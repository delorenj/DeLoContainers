# Nerd Dictation Container

Offline speech-to-text container using [nerd-dictation](https://github.com/ideasman42/nerd-dictation) and VOSK-API.

## Features
- Offline speech recognition
- Customizable text processing
- Supports multiple audio input methods
- X11 input simulation
- Pre-loads model on start for faster dictation activation (`--suspend-on-start`)

## Quick Start

1.  **Build and Start the Container:**
    This command builds the image if needed, starts the container, loads the VOSK model into memory, and then suspends the process. The initial model load might take several minutes depending on your system and the model size.
    ```bash
    docker compose up -d --build
    ```
    *(You only need to run this once after starting your machine or if you manually stop the container.)*

2.  **Use Dictation:**
    a.  **Resume & Start Recording:**
        ```bash
        docker compose exec nerd-dictation nerd-dictation resume
        ```
    b.  **Speak now...**
    c.  **Stop Recording & Output Text:**
        ```bash
        docker compose exec nerd-dictation nerd-dictation end
        ```
        *(Alternatively, use `suspend` instead of `end` to pause recording without exiting the process, keeping it ready in memory.)*

## Configuration

### Model Management
- Default model is stored in `./model`
- To use a different model:
  1. Download from [VOSK models](https://alphacephei.com/vosk/models)
  2. Unzip into `./model` directory
  3. Restart the container (`docker compose restart nerd-dictation`) to load the new model.

### Custom Processing
Create `./config/nerd-dictation.py` to customize text processing. Example:
```python
def nerd_dictation_process(text):
    # Custom text processing here
    return text.upper()
```

## Usage Tips

1.  **Keyboard Shortcuts:** For the best experience, bind the `resume` and `end` (or `suspend`) commands to keyboard shortcuts:
    *   Start Dictation: `docker compose exec nerd-dictation nerd-dictation resume`
    *   Stop Dictation: `docker compose exec nerd-dictation nerd-dictation end`
    *   Pause Dictation: `docker compose exec nerd-dictation nerd-dictation suspend`

2.  **Check Status:** You can see if the process is running/suspended via logs:
    ```bash
    docker compose logs nerd-dictation
    ```

## Troubleshooting

### Audio Issues
Ensure pulseaudio is running on host:
```bash
pulseaudio --start
```
Verify the correct audio device is being used (check `compose.yml` command arguments).

### X11 Issues
Ensure X11 is running and DISPLAY is set correctly.

## Changelog

- 2025-04-01: Initial container setup
- 2025-04-01: Configured `--suspend-on-start` for faster activation after initial load. Updated README with new workflow.