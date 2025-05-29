# YouTube Playlist Downloader Suite

A collection of shell scripts for downloading YouTube playlists and individual videos with different output formats and workflows - from simple MP4 files for video editing to broadcast-ready MXF files for playout servers.

## Scripts Overview

This repository contains two complementary approaches:

### 1. **Playlist Downloader** (`download_playlist.sh`)
- **Purpose**: Download playlists in reverse chronological order for media production workflows
- **Output**: MP4 files with systematic naming
- **Best for**: Content creators, video editors, media servers (Plex, Jellyfin)
- **Features**: CSV logging, flexible episode numbering, delayed series releases

### 2. **Broadcast-Ready Downloader** (`yt_to_server.sh` / `playlist_to_server.sh`)
- **Purpose**: Download and convert to broadcast-standard MXF files with automatic FTP upload
- **Output**: MXF files ready for playout servers
- **Best for**: Broadcast stations, professional media workflows
- **Features**: Audio normalization, broadcast specs, direct server upload

---

## Playlist Downloader (`download_playlist.sh`)

### Purpose
Designed for content creators who need to download YouTube playlists in reverse chronological order with systematic file naming for media production workflows.

### Key Features
- Downloads playlists in best available MP4 quality using yt-dlp
- Reverses episode order (oldest video becomes episode 01)
- Systematic file renaming with customizable prefixes
- CSV generation with metadata and headers
- Activity logging for successful/failed downloads
- Flexible starting points for both episode numbering and playlist position
- File overwrite confirmation (or force mode)
- Continues processing on errors rather than stopping
- Works with any YouTube playlist

### Prerequisites
- `yt-dlp` (recommended over youtube-dl)
- `jq` for JSON parsing
- `ffmpeg` for video format conversion
- Bash shell environment

### Installation
```bash
# Install yt-dlp (recommended)
pip install yt-dlp

# Install jq (Ubuntu/Debian)
sudo apt-get install jq ffmpeg
# OR (macOS)
brew install jq ffmpeg

# Clone this repository
git clone [your-repo-url]
cd youtube-playlist-downloader
chmod +x download_playlist.sh
```

### Usage

#### Basic Usage
```bash
./download_playlist.sh "PLAYLIST_URL"
```

#### Full Usage
```bash
./download_playlist.sh "PLAYLIST_URL" [OPTIONS]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--code CODE` | Filename prefix | "SHILS" |
| `--year YEAR` | Two-digit year for filenames | Current year |
| `--episode NUM` | Starting episode number | 01 |
| `--start-position NUM` | Starting position in playlist (1-based) | 1 |
| `--force` | Overwrite existing files without confirmation | Ask for confirmation |
| `--no-recode` | Keep original format, don't convert to MP4 | Convert to MP4 |
| `-h, --help` | Show help message | - |

#### Examples

**Download entire playlist with defaults:**
```bash
./download_playlist.sh "https://www.youtube.com/playlist?list=PLGoKk-JZWo1MmiYBheRLklQLW-u068x7d"
# Output: SHILS2501.mp4, SHILS2502.mp4, etc.
```

**Custom show code and year:**
```bash
./download_playlist.sh "https://youtube.com/playlist?list=..." --code MYSHOW --year 24
# Output: MYSHOW2401.mp4, MYSHOW2402.mp4, etc.
```

**Start from episode 5, beginning at 3rd video in playlist:**
```bash
./download_playlist.sh "https://youtube.com/playlist?list=..." --episode 05 --start-position 3
# Output: SHILS2505.mp4, SHILS2506.mp4, etc. (starting from 3rd video)
```

**Force overwrite with custom settings:**
```bash
./download_playlist.sh "https://youtube.com/playlist?list=..." --code SHILS --year 25 --force
# Overwrites existing files without asking
```

**Keep original format (no MP4 conversion):**
```bash
./download_playlist.sh "https://youtube.com/playlist?list=..." --no-recode
# Output: SHILS2501.webm, SHILS2502.mkv, etc. (whatever format YouTube provides)
```

### Output

#### Video Files
- Format: `{CODE}{YY}{EE}.mp4`
- Quality: Best available MP4 (up to 1080p)
- Order: Reverse chronological (oldest first)

#### CSV Log
- Filename: `{CODE}_{YEAR}_playlist.csv`
- Contains headers row
- Columns:
  - `original_filename`: Original YouTube filename
  - `new_filename`: Renamed filename
  - `description`: Video description/title
  - `air_date`: Upload date

#### Activity Log
- Filename: `activity.log`
- Contains both successful downloads and failures
- Format: `[TIMESTAMP] STATUS: message`
- Helps track which videos succeeded/failed during batch downloads

### Workflow Integration
This script is designed for media production workflows where:

1. **Content Planning**: Download series with proper episode numbering
2. **Delayed Release**: Start series broadcast ~2 weeks after YouTube upload
3. **Media Server**: Systematic naming for Plex, Jellyfin, etc.
4. **Video Editing**: MP4 format ready for Premiere Pro transcoding

---

## Broadcast-Ready Downloader

A collection of Bash scripts for downloading YouTube videos/playlists and automatically converting them to broadcast-ready MXF files with proper audio normalization, uploading them directly to a playout server via FTP.

### Features

- Download individual YouTube videos or entire playlists
- Convert videos to broadcast-standard MXF format with proper specs
- Normalize audio to broadcast standards (TP -2dB, LKFS -24 +/-2)
- Upload directly to playout server via FTP
- Customize file naming with prefixes and sequential numbering
- Secure credential management
- Trim videos with specific in/out points
- MP4 output option for local editing

### Requirements

- Linux or macOS system
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Enhanced YouTube downloader
- [ffmpeg](https://ffmpeg.org/) - Video conversion utility with MXF support
- FTP access to your playout server

### Dependencies Installation

#### Ubuntu/Debian
```bash
# Install ffmpeg
sudo apt update
sudo apt install ffmpeg

# Install yt-dlp
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```

#### macOS
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install ffmpeg and yt-dlp
brew install ffmpeg yt-dlp
```

### Setup

1. Make scripts executable:
   ```bash
   chmod +x yt_to_server.sh playlist_to_server.sh
   ```

2. Create credentials file:
   ```bash
   nano ~/.ftp_credentials
   ```

3. Add FTP details:
   ```bash
   FTP_SERVER="your.server.address"
   FTP_PATH="/path/on/server"
   FTP_USER="username"
   FTP_PASS="password"
   ```

4. Secure credentials:
   ```bash
   chmod 600 ~/.ftp_credentials
   ```

### Usage

#### Individual Videos
```bash
./yt_to_server.sh "https://www.youtube.com/watch?v=VIDEO_ID" "OUTPUT_FILENAME"

# With trimming
./yt_to_server.sh -t 00:01:30 -o 00:45:20 "https://www.youtube.com/watch?v=VIDEO_ID" "SHILS_001"

# Output as MP4 for local editing
./yt_to_server.sh -f mp4 "https://www.youtube.com/watch?v=VIDEO_ID" "SHILS_001"
```

#### Playlists
```bash
# Basic usage (creates SHILS_001.mxf, SHILS_002.mxf, etc.)
./playlist_to_server.sh "https://www.youtube.com/playlist?list=PLAYLIST_ID"

# Custom prefix and numbering
./playlist_to_server.sh -p "LECTURE_" -s 5 -d 2 "https://www.youtube.com/playlist?list=PLAYLIST_ID"

# Download as MP4 files to local directory
./playlist_to_server.sh -f mp4 -dir "./premiere_files" "https://www.youtube.com/playlist?list=PLAYLIST_ID"
```

### Video Output Specifications (MXF)

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

---

## When to Use Which Script

### Use **Playlist Downloader** (`download_playlist.sh`) when:
- Building a media library for streaming servers (Plex, Jellyfin)
- Preparing content for video editing in Premiere Pro
- Need systematic episode numbering in reverse chronological order
- Want detailed CSV logging of metadata
- Planning delayed content releases
- Working with educational or series content

### Use **Broadcast-Ready Downloader** when:
- Feeding content directly to broadcast playout systems
- Need broadcast-standard MXF files
- Require audio normalization to broadcast standards
- Want automatic FTP upload to servers
- Working in professional broadcast environments
- Need precise video trimming capabilities

## Troubleshooting

### Playlist Downloader Issues
**yt-dlp errors:**
- Update yt-dlp: `pip install --upgrade yt-dlp`
- Check activity.log for specific failure details

**Permission errors:**
- Make script executable: `chmod +x download_playlist.sh`
- Check write permissions in current directory

**Missing dependencies:**
- Install jq for JSON parsing
- Install ffmpeg for video conversion
- Ensure yt-dlp is in PATH

**File conflicts:**
- Use --force flag to overwrite without prompts
- Check activity.log to see which files were skipped/overwritten

### Broadcast Downloader Issues
- **Download fails**: The script will attempt an alternative method automatically
- **FTP upload fails**: Check your credentials and server connectivity
- **Conversion errors**: Ensure you have the latest version of ffmpeg installed
- **Permission denied**: Make sure the scripts are executable (`chmod +x script.sh`)

## Notes

### Playlist Downloader
- Downloads can take significant time for large playlists
- Ensure sufficient disk space before starting
- Script creates CSV log with headers for tracking and verification
- Creates activity.log for monitoring download success/failures
- Script continues processing even if individual videos fail
- Compatible with yt-dlp (recommended over youtube-dl)
- Files are overwritten with confirmation unless --force is used

### Broadcast Downloader (playlist_to_server / yt_to_server)
- MXF conversion requires significant processing time and disk space
- Verify ffmpeg MXF support before use
- Test FTP credentials before batch operations
- Monitor server disk space when uploading multiple files

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with various playlists and video types
5. Submit a pull request

## License

MIT License - Feel free to modify and distribute.
