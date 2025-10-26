"""A simple test script on how to put a soundtrack to a movie."""

from moviepy import *


# We load a movie and replace the sound with some music:

movie = VideoFileClip("../media/stars.mp4").with_audio(
    AudioFileClip("../media/chill-beat.mp3").subclipped(0, 5)
)


# If the soundtrack is longer than the movie, then at the end of the clip
# it will freeze on the last frame and wait for the clip to finish.
# If you don't want that, uncomment the next line:

# ~ movie.audio = movie.audio.with_duration(movie.duration)

movie.write_videofile("jooo.mp4")
