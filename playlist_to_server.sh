#!/bin/bash

# Playlist to YouTube Video Downloader, Converter, and FTP Uploader with Trimming
# This script processes a YouTube playlist, converting each video to MXF format
# and uploading directly to an FTP server with audio normalization

# Load credentials from hidden file
if [ -f ~/.ftp_credentials ]; then
  source ~/.ftp_credentials
else
  echo "Error: FTP credentials file not found. Please create ~/.ftp_credentials"
  echo "Example content for ~/.ftp_credentials:"
  echo 'FTP_SERVER="server_address"'
  echo 'FTP_PATH="/path/on/server"'
  echo 'FTP_USER="username"'
  echo 'FTP_PASS="password"'
  exit 1
fi

# Default parameters
PREFIX="SHILS_"    # Default prefix for generated filenames
START_NUMBER=1     # Starting number for sequential naming
PADDING=3          # Number of digits to pad with zeros
TRIM_START="0"     # Default: no trimming from start
TRIM_END="0"       # Default: no trimming from end

# Function to show usage information
show_usage() {
  echo "Usage: $0 [options] youtube_playlist_url"
  echo "Options:"
  echo "  -p, --prefix PREFIX       Filename prefix (default: SHILS_)"
  echo "  -s, --start NUMBER        Starting number for sequential naming (default: 1)"
  echo "  -d, --digits NUMBER       Number of digits to pad with zeros (default: 3)"
  echo "  -l, --limit NUMBER        Limit number of videos to download (default: all)"
  echo "  -t, --trim-start TIME     Trim from start of video (format: MM:SS or seconds)"
  echo "  -e, --trim-end TIME       Trim from end of video (format: MM:SS or seconds)"
  echo "  -h, --help                Show this help message"
  echo
  echo "Example:"
  echo "  $0 -p \"SERIES_\" -s 5 -d 2 -t 1:30 -e 20 https://www.youtube.com/playlist?list=PLAYLIST_ID"
  exit 1
}

# Function to convert time format (MM:SS or seconds) to seconds
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
    -e|--trim-end)
      TRIM_END="$2"
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

# Convert trim values to seconds
TRIM_START_SECONDS=$(convert_to_seconds "$TRIM_START")
TRIM_END_SECONDS=$(convert_to_seconds "$TRIM_END")

echo "Getting information about playlist: $PLAYLIST_URL"
if [ "$TRIM_START_SECONDS" != "0" ]; then
  echo "Trimming $TRIM_START from the beginning of each video"
fi
if [ "$TRIM_END_SECONDS" != "0" ]; then
  echo "Trimming $TRIM_END from the end of each video"
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
  echo "Output filename: $output_name.mxf"
  
  # Get video title for logging
  video_title=$(yt-dlp --get-title "$video_url")
  echo "Video title: $video_title"
  
  # Prepare the ffmpeg options for trimming
  TRIM_OPTIONS=""
  
  if [ "$TRIM_START_SECONDS" != "0" ]; then
    TRIM_OPTIONS="$TRIM_OPTIONS -ss $TRIM_START"
  fi
  
  if [ "$TRIM_END_SECONDS" != "0" ]; then
    # Get video duration using yt-dlp
    echo "Getting video duration..."
    DURATION=$(yt-dlp --get-duration "$video_url")
    echo "Video duration: $DURATION"
    
    # Convert duration to seconds
    DURATION_SECONDS=$(convert_to_seconds "$DURATION")
    
    # Calculate end time
    END_TIME=$((DURATION_SECONDS - TRIM_END_SECONDS))
    
    # Only apply if we have a positive duration
    if [ $END_TIME -gt 0 ]; then
      if [ "$TRIM_START_SECONDS" != "0" ]; then
        # If we're also trimming from start, adjust the duration
        DURATION=$((END_TIME - TRIM_START_SECONDS))
        TRIM_OPTIONS="$TRIM_OPTIONS -t $DURATION"
      else
        # If not trimming from start, use end time directly
        TRIM_OPTIONS="$TRIM_OPTIONS -t $END_TIME"
      fi
    else
      echo "Warning: Trim end time is greater than video duration. Using full video."
    fi
  fi
  
  echo "Using trim options: $TRIM_OPTIONS"
  
  # Download, convert, and upload in one step with audio normalization and trimming
  echo "Downloading, converting, and uploading..."
  
  yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' \
    -o - "$video_url" | \
    ffmpeg -i pipe:0 \
    $TRIM_OPTIONS \
    -c:v mpeg2video -profile:v 0 -level:v 2 -b:v 30M \
    -pix_fmt yuv422p -s 1920x1080 -flags +ilme+ildct -top 1 \
    -aspect 16:9 -r ntsc \
    -c:a pcm_s16le -ar 48000 -ac 2 \
    -af "loudnorm=I=-24:TP=-2:LRA=7:print_format=summary" \
    -f mxf "ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER$FTP_PATH/${output_name}.mxf"
  
  if [ $? -eq 0 ]; then
    echo "Success: $video_title uploaded as $output_name.mxf"
  else
    echo "Error processing video. Trying alternative method..."
    
    # Try downloading to temporary file first
    TMP_FILE="temp_${output_name}.mp4"
    echo "Downloading to temporary file..."
    
    yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' \
      -o "$TMP_FILE" "$video_url"
      
    if [ $? -eq 0 ]; then
      echo "Download successful. Converting and uploading..."
      
      ffmpeg -i "$TMP_FILE" \
        $TRIM_OPTIONS \
        -c:v mpeg2video -profile:v 0 -level:v 2 -b:v 30M \
        -pix_fmt yuv422p -s 1920x1080 -flags +ilme+ildct -top 1 \
        -aspect 16:9 -r ntsc \
        -c:a pcm_s16le -ar 48000 -ac 2 \
        -af "loudnorm=I=-24:TP=-2:LRA=7:print_format=summary" \
        -f mxf "ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER$FTP_PATH/${output_name}.mxf"
      
      # Clean up temp file
      rm "$TMP_FILE"
      
      if [ $? -eq 0 ]; then
        echo "Conversion and upload successful!"
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