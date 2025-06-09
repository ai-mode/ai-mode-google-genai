# Google Generative AI Backend for AI Mode

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Installation](#installation)
  - [Git Installation](#git-installation)
  - [Package Manager (Future)](#package-manager-future)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Model Selection](#model-selection)
  - [Integration with AI Mode Features](#integration-with-ai-mode-features)
  - [Advanced Configuration](#advanced-configuration)
- [Related Resources](#related-resources)
  - [AI Mode Ecosystem](#ai-mode-ecosystem)
  - [Documentation and Community](#documentation-and-community)
- [Legal Notice](#legal-notice)

## Overview

The Google Generative AI backend for `ai-mode` provides seamless integration with Google's powerful Generative AI models. It acts as a bridge between `ai-mode`'s intelligent AI features and Google's cutting-edge Gemini models, enabling you to leverage the latest Gemini 1.0, 1.5, 2.0, and 2.5 variants directly within your Emacs environment.

This backend plugin simplifies access to Google's Generative AI API, handling all necessary communication, authentication, and response processing. This allows `ai-mode` to harness Google's advanced language understanding and generation capabilities, enhancing your coding and text editing workflows without disrupting your focus.

## Key Features

- **Extensive Model Support**: Access a wide range of Google Gemini models, including stable releases like `gemini-1.5-pro`, `gemini-1.5-flash`, `gemini-2.0-flash`, and cutting-edge preview models such as `gemini-2.5-pro-preview` and `gemini-2.5-flash-preview`, all through a unified `ai-mode` interface.
- **Flexible Configuration**: Fine-tune AI responses by customizing parameters like sampling temperature, maximum output tokens, and other model-specific settings for each interaction.
- **Native API Integration**: Direct and secure communication with the Google Generative AI API, ensuring robust authentication and efficient request handling.
- **Asynchronous Operations**: All API calls are non-blocking, maintaining Emacs' responsiveness and ensuring a smooth user experience during AI interactions.
- **Unified Model Management**: Easily select and switch between different Google Gemini offerings directly within `ai-mode`'s intuitive model selection interface.

## Installation

### Git Installation

To get started, clone the repository into your Emacs plugins directory:

```bash
cd ~/.emacs.d/plugins
git clone --recursive https://github.com/ai-mode/ai-mode-google-genai
```

Next, update your `.emacs` configuration file to include the new plugin:

```elisp
(add-to-list 'load-path "~/.emacs.d/plugins/ai-mode-google-genai")
(require 'ai-mode-google-genai)
```

Alternatively, you can use `use-package` for a more modular setup:

```elasp
(use-package ai-mode-google-genai
  :load-path "~/.emacs.d/plugins/ai-mode-google-genai"
  :config
  (setq ai-mode--models-providers
        (append ai-mode--models-providers '(ai-mode-google-genai--get-models)))
  (setq ai-chat--models-providers
        (append ai-chat--models-providers '(ai-mode-google-genai--get-models))))
```

### Package Manager (Future)

This backend may be available through Emacs package archives (e.g., MELPA) in the future. Check the official `ai-mode` repository or MELPA for updates on package availability.

## Configuration

To enable the Google Generative AI backend, you need to set your API key in your `.emacs` file. **It is highly recommended to store your API key securely and avoid committing it directly into version control.**

```elisp
(setq ai-mode-google-genai--api-key "your-api-key-here")
```

Ensure your API key is valid and has the necessary permissions for making API requests to the Google Generative AI API to ensure seamless interaction.

## Usage

Once configured, the Google Generative AI backend integrates seamlessly with `ai-mode`, allowing you to leverage Google Gemini models across all `ai-mode` features.

### Model Selection

The backend provides access to multiple Google Gemini models, each with different configurations and use cases. These include:

-   **Latest Preview Models**:
    -   `gemini-2.5-pro-preview-06-05` (with temperature variants 0.1, 1.0)
    -   `gemini-2.5-flash-preview-05-20` (with temperature variants 0.1, 1.0)
-   **Stable Versions**:
    -   `gemini-2.0-flash`
    -   `gemini-1.5-pro`
    -   `gemini-1.5-flash`

You can switch between these models using `ai-mode`'s model selection interface, typically accessible via `M-x ai-mode-select-model` or through `ai-chat`'s model selection options.

### Integration with AI Mode Features

The Google Generative AI backend enhances all core `ai-mode` capabilities:

-   **Code Completion & Generation**: Receive intelligent code suggestions, complete snippets, and generate entire functions leveraging Gemini's understanding of programming languages and context.
-   **Chat Interactions**: Engage in conversational AI assistance with Google Gemini models through `ai-chat`, ideal for debugging, brainstorming, or general queries.
-   **Code Refactoring**: Utilize Gemini's analytical capabilities to improve code structure, readability, and efficiency.
-   **Documentation Generation**: Automatically create or enhance comments, docstrings, and other documentation based on your code.
-   **Custom Prompts**: Send any arbitrary prompt or instruction to Google Gemini models through the unified `ai-mode` interface for diverse tasks.

### Advanced Configuration

You can customize model behavior globally or for specific use cases by setting these variables in your Emacs configuration:

```elisp
;; Set custom parameters for specific models
(setq ai-mode-google-genai--model-temperature 0.2)  ; Lower temperature for more focused responses
(setq ai-mode-google-genai--default-max-tokens 2000)  ; Increase the maximum token limit for longer outputs
(setq ai-mode-google-genai-request-timeout 120)  ; Extend API request timeout for complex or lengthy operations
```

The backend handles all API communication, authentication, and response processing automatically, allowing you to focus on your work while benefiting from Google's powerful Generative AI models.

### Adding Custom Models

You can extend the list of available Google Generative AI models by adding your own custom configurations to `ai-mode`'s model providers. This is useful if you want to test specific model versions, experiment with different `temperature` or `max-tokens` settings, or integrate models not explicitly listed by default.

To add a custom model, modify your Emacs configuration file (e.g., `.emacs` or `init.el`) like this:

```elisp
(add-to-list 'ai-mode--models-providers
             (lambda ()
               (list (ai-mode-google-genai--make-model "gemini-2.0-pro-new-release"
                                                       :name "My Custom Gemini 2.0 Pro"
                                                       :temperature 0.5
                                                       :max-tokens 8192))))

;; If you use ai-chat, also add it to ai-chat--models-providers
(add-to-list 'ai-chat--models-providers
             (lambda ()
               (list (ai-mode-google-genai--make-model "gemini-2.0-pro-new-release"
                                                       :name "My Custom Gemini 2.0 Pro"
                                                       :temperature 0.5
                                                       :max-tokens 8192))))
```

In this example:
- `gemini-2.0-pro-new-release` is the model version (which needs to be a valid Google Generative AI model name).
- `:name` sets a custom display name for your model in `ai-mode`'s selection interface.
- `:temperature` and `:max-tokens` allow you to override the default settings for this specific model.

Remember to restart Emacs or re-evaluate your configuration after making changes. Your custom model will then appear in `ai-mode`'s model selection list.

## Related Resources

### AI Mode Ecosystem

- **[AI Mode](https://github.com/ai-mode/ai-mode)**: The core AI-powered Emacs extension that this backend supports.
- **[AI Mode OpenAI](https://github.com/ai-mode/ai-mode-openai)**: OpenAI backend for `ai-mode`.
- **[AI Mode Anthropic](https://github.com/ai-mode/ai-mode-anthropic)**: Anthropic Claude backend for `ai-mode`.
- **[AI Mode DeepSeek](https://github.com/ai-mode/ai-mode-deepseek)**: DeepSeek backend for `ai-mode`.
- **[AI Mode Hugging Face](https://github.com/ai-mode/ai-mode-hf)**: Hugging Face models backend for `ai-mode`.
- **[AI Mode Google Generative AI](https://github.com/ai-mode/ai-mode-google-genai)**: Google Generative AI backend for `ai-mode`.

### Documentation and Community

- **[AI Mode Discussions](https://github.com/ai-mode/ai-mode/discussions)**: Community forum for questions, ideas, and support.

## Legal Notice

This project is an independent open-source initiative and is not affiliated with, endorsed by, or sponsored by Google LLC.

Google, Gemini, and related marks are trademarks or registered trademarks of Google LLC. All other trademarks mentioned in this documentation are the property of their respective owners.

The use of Google Generative AI's API is subject to Google's terms of service and usage policies. Users are responsible for ensuring their usage complies with all applicable terms and regulations.
