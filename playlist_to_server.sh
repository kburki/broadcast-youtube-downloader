#!/bin/bash

# Playlist to YouTube Video Downloader, Converter, and FTP Uploader with Trimming
# This script processes a YouTube playlist, converting each video to MXF or MP4 format

# Load credentials from hidden file if uploading to FTP
if [ -f ~/.ftp_credentials ]; then
  source ~/.ftp_credentials
fi

# Default parameters
PREFIX="SHILS_"       # Default prefix for generated filenames
START_NUMBER=1        # Starting number for sequential naming
PADDING=3             # Number of digits to pad with zeros
TRIM_START="0"        # Default: no trimming from start
OUT_POINT=""          # Default: no specific out point
OUTPUT_FORMAT="mxf"   # Default: MXF format
LOCAL_OUTPUT_DIR="./OUT" # Default local output directory for MP4 files

# Function to show usage information
show_usage() {
  echo "Usage: $0 [options] youtube_playlist_url"
  echo "Options:"
  echo "  -p, --prefix PREFIX       Filename prefix (default: SHILS_)"
  echo "  -s, --start NUMBER        Starting number for sequential naming (default: 1)"
  echo "  -d, --digits NUMBER       Number of digits to pad with zeros (default: 3)"
  echo "  -l, --limit NUMBER        Limit number of videos to download (default: all)"
  echo "  -t, --trim-start TIME     Trim from start of video (format: HH:MM:SS or seconds)"
  echo "  -o, --out-point TIME      Specify out point/end time (format: HH:MM:SS)"
  echo "  -f, --format FORMAT       Output format: mxf or mp4 (default: mxf)"
  echo "  -dir, --directory DIR     Local output directory for MP4 files (default: ./OUT)"
  echo "  -h, --help                Show this help message"
  echo
  echo "Examples:"
  echo "  $0 -p \"SERIES_\" -s 5 -d 2 -t 00:01:30 -o 00:45:20 https://www.youtube.com/playlist?list=PLAYLIST_ID"
  echo "  $0 -f mp4 -dir \"./mp4_files\" https://www.youtube.com/playlist?list=PLAYLIST_ID"
  exit 1
}

# Function to convert time format (HH:MM:SS or seconds) to seconds
convert_to_seconds() {
  local time_str="$1"
  local seconds=0
  
  if [[ "$time_str" == *":"* ]]; then
    # Time format MM:SS or HH:MM:SS
    IFS=':' read -ra TIME_PARTS <<< "$time_str"
    if [ ${#TIME_PARTS[@]} -eq 3 ]; then
      # HH:MM:SS format
      seconds=$((${TIME_PARTS[0]}*3600 + ${TIME_PARTS[1]}*60 + ${TIME_PARTS[2]}))
    elif [ ${#TIME_PARTS[@]} -eq 2 ]; then
      # MM:SS format
      seconds=$((${TIME_PARTS[0]}*60 + ${TIME_PARTS[1]}))
    fi
  else
    # Already in seconds
    seconds=$time_str
  fi
  
  echo $seconds
}

# Parse command line arguments
LIMIT=""  # No limit by default

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--prefix)
      PREFIX="$2"
      shift 2
      ;;
    -s|--start)
      START_NUMBER="$2"
      shift 2
      ;;
    -d|--digits)
      PADDING="$2"
      shift 2
      ;;
    -l|--limit)
      LIMIT="$2"
      shift 2
      ;;
    -t|--trim-start)
      TRIM_START="$2"
      shift 2
      ;;
    -o|--out-point)
      OUT_POINT="$2"
      shift 2
      ;;
    -f|--format)
      OUTPUT_FORMAT=$(echo "$2" | tr '[:upper:]' '[:lower:]')
      if [[ "$OUTPUT_FORMAT" != "mxf" && "$OUTPUT_FORMAT" != "mp4" ]]; then
        echo "Error: Format must be 'mxf' or 'mp4'"
        show_usage
      fi
      shift 2
      ;;
    -dir|--directory)
      LOCAL_OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      show_usage
      ;;
    -*|--*)
      echo "Unknown option: $1"
      show_usage
      ;;
    *)
      PLAYLIST_URL="$1"
      shift
      ;;
  esac
done

# Check if playlist URL was provided
if [ -z "$PLAYLIST_URL" ]; then
  echo "Error: No playlist URL provided"
  show_usage
fi

# Check if MXF format requires FTP credentials
if [ "$OUTPUT_FORMAT" = "mxf" ] && [ -z "$FTP_SERVER" ]; then
  echo "Error: FTP credentials are required for MXF output. Please create ~/.ftp_credentials or use MP4 output."
  exit 1
fi

# Ensure output directory exists for MP4 output
if [ "$OUTPUT_FORMAT" = "mp4" ]; then
  mkdir -p "$LOCAL_OUTPUT_DIR"
fi

echo "Getting information about playlist: $PLAYLIST_URL"
echo "Output format: $OUTPUT_FORMAT"
if [ "$TRIM_START" != "0" ]; then
  echo "Trimming $TRIM_START from the beginning of each video"
fi
if [ -n "$OUT_POINT" ]; then
  echo "Setting out point to $OUT_POINT for each video"
fi

# Get playlist info and list of video URLs
playlist_info=$(yt-dlp --flat-playlist --print "%(title)s" "$PLAYLIST_URL")
if [ $? -ne 0 ]; then
  echo "Error: Failed to get playlist information. Check the URL and your internet connection."
  exit 1
fi

video_ids=$(yt-dlp --flat-playlist --get-id "$PLAYLIST_URL")
if [ $? -ne 0 ]; then
  echo "Error: Failed to get video IDs from playlist."
  exit 1
fi

# Count videos in playlist
total_videos=$(echo "$video_ids" | wc -l)
total_videos=$(echo $total_videos) # Trim whitespace

echo "Found $total_videos videos in playlist"

# Apply limit if specified
if [ -n "$LIMIT" ] && [ "$LIMIT" -lt "$total_videos" ]; then
  echo "Limiting to first $LIMIT videos"
  video_ids=$(echo "$video_ids" | head -n "$LIMIT")
  total_videos=$LIMIT
fi

# Process each video
current_number=$START_NUMBER
count=1

echo "$video_ids" | while read -r video_id; do
  # Format current number with leading zeros based on padding setting
  if [ "$PADDING" -gt 0 ]; then
    padded_number=$(printf "%0${PADDING}d" $current_number)
    output_name="${PREFIX}${padded_number}"
  else
    output_name="${PREFIX}${current_number}"
  fi
  
  video_url="https://www.youtube.com/watch?v=$video_id"
  
  echo "Processing video $count of $total_videos: $video_id"
  if [ "$OUTPUT_FORMAT" = "mp4" ]; then
    echo "Output filename: $LOCAL_OUTPUT_DIR/$output_name.mp4"
  else
    echo "Output filename: $output_name.mxf (uploading to server)"
  fi
  
  # Get video title for logging
  video_title=$(yt-dlp --get-title "$video_url")
  echo "Video title: $video_title"
  
  # Prepare the ffmpeg options for trimming
  TRIM_OPTIONS=""
  
  if [ "$TRIM_START" != "0" ]; then
    TRIM_OPTIONS="$TRIM_OPTIONS -ss $TRIM_START"
  fi
  
  if [ -n "$OUT_POINT" ]; then
    if [ "$TRIM_START" != "0" ]; then
      # Convert times to seconds
      START_SECONDS=$(convert_to_seconds "$TRIM_START")
      END_SECONDS=$(convert_to_seconds "$OUT_POINT")
      
      # Calculate duration
      DURATION=$((END_SECONDS - START_SECONDS))
      
      if [ $DURATION -gt 0 ]; then
        # Use duration if positive
        TRIM_OPTIONS="$TRIM_OPTIONS -t $DURATION"
      else
        echo "Error: Out point is before start point. Using full video from start point."
      fi
    else
      # No start trim, just use the out point directly
      TRIM_OPTIONS="$TRIM_OPTIONS -to $OUT_POINT"
    fi
  fi
  
  # Prepare output settings based on format
  if [ "$OUTPUT_FORMAT" = "mxf" ]; then
    # MXF format with broadcast settings
    OUTPUT_SETTINGS="-c:v mpeg2video -profile:v 0 -level:v 2 -b:v 30M \
      -pix_fmt yuv422p -s 1920x1080 -flags +ilme+ildct -top 1 \
      -aspect 16:9 -r ntsc \
      -c:a pcm_s16le -ar 48000 -ac 2 \
      -af \"loudnorm=I=-24:TP=-2:LRA=7:print_format=summary\" \
      -f mxf"
    
    # Set output path for MXF (FTP server)
    OUTPUT_PATH="\"ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER$FTP_PATH/${output_name}.mxf\""
  else
    # MP4 format with high quality but compatible settings for editing
    OUTPUT_SETTINGS="-c:v libx264 -profile:v high -level:v 4.1 -crf 18 \
      -pix_fmt yuv420p -s 1920x1080 \
      -aspect 16:9 \
      -c:a aac -b:a 384k -ar 48000 -ac 2 \
      -af \"loudnorm=I=-24:TP=-2:LRA=7:print_format=summary\" \
      -movflags +faststart \
      -f mp4"
    
    # Set output path for MP4 (local directory)
    OUTPUT_PATH="\"$LOCAL_OUTPUT_DIR/${output_name}.mp4\""
  fi
  
  # Build the ffmpeg command
  FFMPEG_CMD="yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' -o - \"$video_url\" | \
    ffmpeg -i pipe:0 $TRIM_OPTIONS $OUTPUT_SETTINGS $OUTPUT_PATH"
  
  # Execute the command
  eval $FFMPEG_CMD
  
  if [ $? -eq 0 ]; then
    if [ "$OUTPUT_FORMAT" = "mp4" ]; then
      echo "Success: $video_title saved as $LOCAL_OUTPUT_DIR/${output_name}.mp4"
    else
      echo "Success: $video_title uploaded as ${output_name}.mxf"
    fi
  else
    echo "Error processing video. Trying alternative method..."
    
    # Try downloading to temporary file first
    TMP_FILE="temp_${output_name}.mp4"
    echo "Downloading to temporary file..."
    
    yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' -o "$TMP_FILE" "$video_url"
      
    if [ $? -eq 0 ]; then
      echo "Download successful. Converting..."
      
      # Build and execute ffmpeg command
      FFMPEG_CMD="ffmpeg -i \"$TMP_FILE\" $TRIM_OPTIONS $OUTPUT_SETTINGS $OUTPUT_PATH"
      eval $FFMPEG_CMD
      
      # Clean up temp file
      rm "$TMP_FILE"
      
      if [ $? -eq 0 ]; then
        if [ "$OUTPUT_FORMAT" = "mp4" ]; then
          echo "Success: $video_title saved as $LOCAL_OUTPUT_DIR/${output_name}.mp4"
        else
          echo "Success: $video_title uploaded as ${output_name}.mxf"
        fi
      else
        echo "Failed to process video: $video_title"
        echo "Continuing with next video..."
      fi
    else
      echo "Failed to download video: $video_title"
      echo "Continuing with next video..."
    fi
  fi
  
  # Increment for next video
  current_number=$((current_number + 1))
  count=$((count + 1))
  
  # Add a short delay between videos to avoid rate limiting
  sleep 2
done

echo "Playlist processing complete!"