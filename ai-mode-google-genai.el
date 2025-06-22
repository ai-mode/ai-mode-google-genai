;;; ai-mode-google-genai.el --- ai-mode integration with Google Generative AI API  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Alex

;; Author: Alex <Lispython@users.noreply.github.com>
;; Maintainer: Alex <Lispython@users.noreply.github.com>
;; URL: https://github.com/ai-mode/ai-mode-google-genai
;; Version: 1.0.0
;; Package-Requires: ((emacs "26.1"))
;; Keywords: help tools ai

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package provides a backend for `ai-mode` to integrate with the
;; Google Generative AI API (Gemini models). It enables `ai-mode` to
;; utilize Google's powerful AI capabilities for tasks like code
;; generation, chat interactions, refactoring, and documentation
;; within Emacs. It handles API requests, authentication, and response
;; parsing, offering a seamless experience for developers and writers.
;;

;;; Code:

;; Happy coding! ;)

(require 'cl-lib)
(require 'ai-utils)
(require 'ai-mode-adapter-api)
(require 'url)

(defgroup ai-mode-google-genai nil
  "Integration with Google Generative AI API."
  :prefix "ai-mode-google-genai"
  :group 'ai-mode
  :link '(url-link :tag "Repository" "https://github.com/ai-mode/ai-mode-google-genai"))

(defcustom ai-mode-google-genai--model-temperature 0.7
  "Sampling temperature to use, between 0 and 2."
  :type '(choice number (const nil))
  :group 'ai-mode-google-genai)

(defcustom ai-mode-google-genai--default-max-tokens 65536
  "Maximum number of tokens to generate in the completion."
  :type '(choice integer (const nil))
  :group 'ai-mode-google-genai)

(defcustom ai-mode-google-genai--api-key ""
  "Key for accessing the Google Generative AI API."
  :type 'string
  :group 'ai-mode-google-genai)

(defcustom ai-mode-google-genai-request-timeout 60
  "Timeout for Google Generative AI requests."
  :type '(choice integer (const nil))
  :group 'ai-mode-google-genai)

(defvar ai-mode-google-genai--base-url "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent")

(defcustom ai-mode-google-genai--struct-type-role-mapping
  '((system . "user")
    (assistant . "model")
    (user . "user")
    (agent-instructions . "user")
    (global-system-prompt . "user")
    (global-memory-item . "user")
    (buffer-bound-prompt . "user")
    (additional-context . "user")
    (user-input . "user")
    (assistant-response . "model")
    (action-context . "user")
    (file-context . "user")
    (project-context . "user")
    (file-metadata . "user"))
  "Structure type to role mapping for Google Generative AI API.
Google Gemini API supports 'user' and 'model' roles."
  :type '(alist :key-type (choice string symbol)
                :value-type string)
  :group 'ai-mode-google-genai)

(defcustom ai-mode-google-genai--default-role-mapping
  '(("system" . "user")
    ("assistant" . "model")
    ("user" . "user"))
  "Role mapping from structure types to roles for Google Generative AI API."
  :group 'ai-mode-google-genai)

(defun ai-mode-google-genai--get-role-for-struct-type (struct-type)
  "Return the role for the given STRUCT-TYPE using customizable role mapping."
  (let* ((role-mapping ai-mode-google-genai--struct-type-role-mapping)
         (type (if (symbolp struct-type) (symbol-name struct-type) struct-type))
         (struct-type-string (if (symbolp struct-type) (symbol-name struct-type) struct-type))
         (role (if (symbolp struct-type)
                   (cdr (cl-assoc struct-type role-mapping))
                 (cdr (cl-assoc type role-mapping :test #'equal)))))
    (or role struct-type-string)))

(defun ai-mode-google-genai--convert-struct (item role-mapping)
  "Convert a single ITEM into Google Gemini message format using ROLE-MAPPING."
  (cond
   ((and (listp item) (consp (car item)) (stringp (caar item)))
    (let* ((role (cdr (assoc "role" item)))
           (model-role (or (cdr (assoc role role-mapping))
                           (ai-mode-google-genai--get-role-for-struct-type role)))
           (content (ai-mode-adapter--get-struct-content item)))
      `(("role" . ,model-role)
        ("parts" . (((text . ,content)))))))
   ((plistp item)
    (let* ((type (ai-mode-adapter--get-struct-type item))
           (model-role (ai-mode-google-genai--get-role-for-struct-type type))
           (content (ai-mode-adapter--get-struct-content item)))
      `(("role" . ,model-role)
        ("parts" . (((text . ,content)))))))))


(defun ai-mode-google-genai--structs-to-model-messages (messages model)
  "Convert common CONTEXT structure into Google Gemini API messages."
  (let* ((role-mapping (map-elt model :role-mapping)))
    (delq nil (mapcar (lambda (item)
                        (ai-mode-google-genai--convert-struct item role-mapping))
                      messages))))

(defun ai-mode-google-genai--make-types-struct (candidate)
  "Convert a single CANDIDATE into an internal typed structure."
  (let* ((content (cdr (assoc 'content candidate)))
         (parts (if (vectorp (cdr (assoc 'parts content)))
                    (cdr (assoc 'parts content))
                  (vector (cdr (assoc 'parts content)))))
         (text (cdr (assoc 'text (aref parts 0)))))
    (ai-common--make-typed-struct text 'assistant-response)))

(defun ai-mode-google-genai--convert-items-to-context-structs (candidates)
  "Convert CANDIDATES into internal representation."
  (mapcar #'ai-mode-google-genai--make-types-struct candidates))


(cl-defun ai-mode-google-genai--convert-context-to-request-data (context model &key (extra-params nil))
  "Convert CONTEXT associative array to request data format."
  (let* ((temperature (map-elt model :temperature))
         (max-tokens (map-elt model :max-tokens ai-mode-google-genai--default-max-tokens))
         (model-rest-params (map-elt model :rest-params))
         (messages (map-elt context :messages))
         (contents (ai-mode-google-genai--structs-to-model-messages (map-elt context :messages) model))
         (generation-config (append
                             (if max-tokens `(("maxOutputTokens" . ,max-tokens)) nil)
                             (if temperature `(("temperature" . ,temperature)) nil)))
         (payload (append
                   `(("contents" . ,contents))
                   (when generation-config
                     `(("generationConfig" . ,generation-config)))
                   model-rest-params)))
    payload))

(cl-defun ai-mode-google-genai--async-api-request (url request-data callback &key (fail-callback nil) (extra-params nil))
  "Perform an asynchronous execution of REQUEST-DATA to the Google Generative AI API."
  (when (null ai-mode-google-genai--api-key)
    (error "Google Generative AI API key is not set"))

  (let* ((url-with-key (format "%s?key=%s" url ai-mode-google-genai--api-key))
         (timeout (map-elt extra-params :timeout ai-mode-google-genai-request-timeout))
         (encoded-request-data (encode-coding-string (json-encode request-data) 'utf-8))
         (headers  `(("Content-Type" . "application/json"))))
    (ai-utils--async-request url-with-key "POST" encoded-request-data headers callback :timeout timeout)))


(defun ai-mode-google-genai--json-error-to-typed-struct (json-response)
  "Convert JSON-RESPONSE error into a typed structure with type 'error."
  (let* ((error (cdr (assoc 'error json-response)))
         (message (cdr (assoc 'message error)))
         (additional-props (list :code (cdr (assoc 'code error))
                                 :status (cdr (assoc 'status error)))))
    (ai-common--make-typed-struct message 'error :additional-props additional-props)))


(cl-defun ai-mode-google-genai--async-send-context (context model &key success-callback (fail-callback nil) (extra-params nil))
  "Asynchronously execute CONTEXT, extract message from response and call CALLBACK."
  (let* ((api-url (map-elt model :api-url))
         (request-data (ai-mode-google-genai--convert-context-to-request-data context model :extra-params extra-params)))
    (ai-mode-google-genai--async-api-request
     api-url
     request-data
     (lambda (response)
       (if (assoc 'error response)
           (when fail-callback
             (funcall fail-callback request-data (ai-mode-google-genai--json-error-to-typed-struct response)))
         (let* ((candidates (cdr (assoc 'candidates response)))
                (messages (ai-mode-google-genai--convert-items-to-context-structs candidates)))
           (funcall success-callback messages))))
     :fail-callback fail-callback
     :extra-params extra-params)))

(defun ai-mode-google-genai--setup-assistant-backend ()
  "Set up the backend for the assistant model."
  'ai-mode-google-genai--async-send-context)

(cl-defun ai-mode-google-genai--make-model (version &key
                                                    name
                                                    max-tokens
                                                    temperature
                                                    (role-mapping ai-mode-google-genai--default-role-mapping)
                                                    rest-params)
  "Create a model configuration."
  (let* ((name (cond (name name)
                     (temperature (format "Google %s (t%s)" version temperature))
                     (t (format "Google %s" version))))
         (api-url (format ai-mode-google-genai--base-url version))
         (model (append `((:name . ,name)
                          (:provider . "Google")
                          (:version . ,version)
                          (:api-url . ,api-url)
                          (:execution-backend . ,'ai-mode-google-genai--async-send-context)
                          (:setup-function . ,'ai-mode-google-genai--setup-assistant-backend)
                          (:role-mapping . ,role-mapping))
                        (if max-tokens `((:max-tokens . ,max-tokens)))
                        (if temperature `((:temperature . ,temperature)))
                        `((:rest-params . ,rest-params)))))
    model))


(defun ai-mode-google-genai--get-models ()
  "Retrieve the list of available models."
  (list
   ;; Latest models with extended variations
   (ai-mode-google-genai--make-model "gemini-2.5-pro-preview-06-05" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-pro-preview-06-05" :temperature 0.1 :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-pro-preview-06-05" :temperature 1.0 :max-tokens 64000)

   (ai-mode-google-genai--make-model "gemini-2.5-flash-preview-05-20" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-flash-preview-05-20" :temperature 0.1 :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-flash-preview-05-20" :temperature 1.0 :max-tokens 64000)

   (ai-mode-google-genai--make-model "gemini-2.5-flash-lite-preview-06-17" :max-tokens 64000)

   ;; Stable versions
   (ai-mode-google-genai--make-model "gemini-2.5-pro" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-pro" :temperature 0.1 :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-pro" :temperature 1.0 :max-tokens 64000)

   (ai-mode-google-genai--make-model "gemini-2.5-flash" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-flash" :temperature 0.1 :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.5-flash" :temperature 1.0 :max-tokens 64000)

   (ai-mode-google-genai--make-model "gemini-2.5-flash-lite" :max-tokens 64000)

   (ai-mode-google-genai--make-model "gemini-2.0-flash" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-2.0-flash-lite" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-1.5-pro" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-1.5-flash" :max-tokens 64000)
   (ai-mode-google-genai--make-model "gemini-1.5-flash-8b" :max-tokens 64000)))

(provide 'ai-mode-google-genai)
;;; ai-mode-google-genai.el ends here
