# Broadcast-Ready YouTube Downloader

A collection of Bash scripts for downloading YouTube videos/playlists and automatically converting them to broadcast-ready MXF files with proper audio normalization, uploading them directly to a playout server via FTP.

## Features

- Download individual YouTube videos or entire playlists
- Convert videos to broadcast-standard MXF format with proper specs
- Normalize audio to broadcast standards (TP -2dB, LKFS -24 +/-2)
- Upload directly to playout server via FTP
- Customize file naming with prefixes and sequential numbering
- Secure credential management

## Requirements

- Linux or macOS system
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Enhanced YouTube downloader
  - Install with: `pip install yt-dlp` or `brew install yt-dlp`
- [ffmpeg](https://ffmpeg.org/) - Video conversion utility
  - Install on Ubuntu/Debian: `sudo apt install ffmpeg`
  - Install on macOS: `brew install ffmpeg`
  - Ensure your ffmpeg installation includes support for MXF format
- FTP access to your playout server

## Dependencies Installation

### Ubuntu/Debian
```bash
# Install ffmpeg
sudo apt update
sudo apt install ffmpeg

# Install yt-dlp
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```

### macOS
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install ffmpeg and yt-dlp
brew install ffmpeg yt-dlp
```

### Verify Installation
Verify that both tools are properly installed:
```bash
ffmpeg -version
yt-dlp --version
```

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/broadcast-youtube-downloader.git
   cd broadcast-youtube-downloader
   ```

2. Make scripts executable:
   ```bash
   chmod +x yt_to_server.sh
   chmod +x playlist_to_server.sh
   ```

3. Create the credentials file:
   ```bash
   nano ~/.ftp_credentials
   ```

4. Add your FTP details to the credentials file:
   ```bash
   FTP_SERVER="your.server.address"
   FTP_PATH="/path/on/server"
   FTP_USER="username"
   FTP_PASS="password"
   ```

5. Secure your credentials file:
   ```bash
   chmod 600 ~/.ftp_credentials
   ```

## Usage

### Individual YouTube Videos

Download and convert a single YouTube video:

```bash
./yt_to_server.sh "https://www.youtube.com/watch?v=VIDEO_ID" "OUTPUT_FILENAME"
```

Example:
```bash
./yt_to_server.sh "https://www.youtube.com/watch?v=dQw4w9WgXcQ" "SHILS2501"
```

### YouTube Playlists

Download and convert an entire YouTube playlist:

```bash
./playlist_to_server.sh [options] "https://www.youtube.com/playlist?list=PLAYLIST_ID"
```

Options:
- `-p, --prefix PREFIX` : Filename prefix (default: "SHILS_")
- `-s, --start NUMBER` : Starting number for sequential naming (default: 1)
- `-d, --digits NUMBER` : Number of digits to pad with zeros (default: 3)
- `-l, --limit NUMBER` : Limit number of videos to download (default: all)
- `-h, --help` : Show help message
- `-t, --trim-start TIME` :  Trim from start of video (format: MM:SS or seconds)"
- `-e, --trim-end TIME`  :    Trim from end of video (format: MM:SS or seconds)"

Examples:
```bash
# Basic usage (will create SHILS_001.mxf, SHILS_002.mxf, etc.)
./playlist_to_server.sh "https://www.youtube.com/playlist?list=PLAYLIST_ID"

# Custom prefix and starting number (creates LECTURE_005.mxf, LECTURE_006.mxf, etc.)
./playlist_to_server.sh -p "LECTURE_" -s 5 "https://www.youtube.com/playlist?list=PLAYLIST_ID"

# Two-digit padding (creates EVENT_01.mxf, EVENT_02.mxf, etc.)
./playlist_to_server.sh -p "EVENT_" -d 2 "https://www.youtube.com/playlist?list=PLAYLIST_ID"

# Download only the first 3 videos from a playlist
./playlist_to_server.sh -l 3 "https://www.youtube.com/playlist?list=PLAYLIST_ID"

# Exact filename with no number (creates SHILS2501.mxf)
./playlist_to_server.sh -p "SHILS2501" -s 1 -d 0 "https://www.youtube.com/playlist?list=PLAYLIST_ID"

# Tripm start and end times from the video 
./yt_to_server.sh -t 1:30 -e 20 'https://www.youtube.com/watch?v=VIDEO_ID' 'SHILS2510'"
```

## New Features

- **Specify End Point**: Instead of trimming a fixed amount from the end, you can now specify an exact out point using `-o` or `--out-point`.
- **MP4 Output Option**: You can now output to MP4 files locally instead of MXF files on the server, making it easier to import into Adobe Premiere.

### Examples

```bash
# Download a video and trim it with specific in/out points
./yt_to_server.sh -t 00:01:30 -o 00:45:20 "https://www.youtube.com/watch?v=VIDEO_ID" "SHILS_001"

# Download a video as MP4 for local editing
./yt_to_server.sh -f mp4 "https://www.youtube.com/watch?v=VIDEO_ID" "SHILS_001"

# Download a playlist as MP4 files to a specific directory
./playlist_to_server.sh -f mp4 -dir "./premiere_files" "https://www.youtube.com/playlist?list=PLAYLIST_ID"

## Video Output Specifications

All videos are converted to the following broadcast-ready specifications:

- Container: MXF
- Video codec: MPEG-2 (profile 0, level 2)
- Bitrate: 30 Mbps
- Color space: YUV 4:2:2
- Resolution: 1920x1080
- Field order: Interlaced, upper field first
- Aspect ratio: 16:9
- Frame rate: NTSC (29.97 fps)
- Audio: PCM 16-bit, 48kHz, stereo
- Audio normalization: TP -2dB, LKFS -24 +/-2

## Troubleshooting

- **Download fails**: The script will attempt an alternative method automatically
- **FTP upload fails**: Check your credentials and server connectivity
- **Conversion errors**: Ensure you have the latest version of ffmpeg installed
- **Permission denied**: Make sure the scripts are executable (`chmod +x script.sh`)

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.