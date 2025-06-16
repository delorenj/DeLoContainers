import click
from moviepy.editor import VideoFileClip


@click.command()
@click.option(
    "--input_video_path",
    type=click.Path(exists=True, dir_okay=False, readable=True),
    required=True,
    help="Path to the input video file.",
)
@click.option(
    "--output_audio_path",
    type=click.Path(writable=True, dir_okay=False),
    required=True,
    help="Path to save the extracted MP3 audio file.",
)
def extract_audio(input_video_path: str, output_audio_path: str):
    """
    Extracts audio from a video file and saves it as an MP3 file.
    """
    print(f"Starting audio extraction from '{input_video_path}'")
    try:
        video_clip = VideoFileClip(input_video_path)
        audio_clip = video_clip.audio

        if audio_clip is None:
            print(f"Error: No audio track found in '{input_video_path}'")
            return

        print(f"Extracting audio to '{output_audio_path}'")
        audio_clip.write_audiofile(output_audio_path)

        video_clip.close()
        if hasattr(audio_clip, "close"):  # Check if audio_clip has a close method
            audio_clip.close()

        print("Audio extraction successful!")

    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    extract_audio()
