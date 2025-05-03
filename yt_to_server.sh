#!/bin/bash

# YouTube Video Downloader, Converter, and FTP Uploader with Trimming
# This script processes a single YouTube video, converting it to MXF format
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
TRIM_START="0"  # Default: no trimming from start
TRIM_END="0"    # Default: no trimming from end

# Function to show usage information
show_usage() {
  echo "Usage: $0 [options] youtube_url output_name"
  echo "Options:"
  echo "  -t, --trim-start TIME    Trim from start of video (format: MM:SS or seconds)"
  echo "  -e, --trim-end TIME      Trim from end of video (format: MM:SS or seconds)"
  echo "  -h, --help               Show this help message"
  echo
  echo "Example:"
  echo "  $0 -t 1:30 -e 20 'https://www.youtube.com/watch?v=VIDEO_ID' 'SHILS_001'"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
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
    -*)
      echo "Unknown option: $1"
      show_usage
      ;;
    *)
      if [ -z "$YT_URL" ]; then
        YT_URL="$1"
        shift
      elif [ -z "$OUTPUT_NAME" ]; then
        OUTPUT_NAME="$1"
        shift
      else
        echo "Too many arguments"
        show_usage
      fi
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$YT_URL" ] || [ -z "$OUTPUT_NAME" ]; then
  echo "Error: Missing required arguments"
  show_usage
fi

echo "Downloading, converting, and uploading to FTP server"
echo "Video URL: $YT_URL"
echo "Output filename: $OUTPUT_NAME.mxf"

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

# Convert trim values to seconds
TRIM_START_SECONDS=$(convert_to_seconds "$TRIM_START")
TRIM_END_SECONDS=$(convert_to_seconds "$TRIM_END")

# Prepare the ffmpeg options for trimming
TRIM_OPTIONS=""

if [ "$TRIM_START_SECONDS" != "0" ]; then
  echo "Trimming $TRIM_START from the beginning of the video"
  TRIM_OPTIONS="$TRIM_OPTIONS -ss $TRIM_START"
fi

if [ "$TRIM_END_SECONDS" != "0" ]; then
  echo "Trimming $TRIM_END from the end of the video"
  
  # Get video duration using yt-dlp
  echo "Getting video duration..."
  DURATION=$(yt-dlp --get-duration "$YT_URL")
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

# Try direct conversion and FTP upload with trimming
echo "Downloading, converting, and uploading directly to FTP..."

# Using yt-dlp to download and pipe to ffmpeg for conversion and direct upload with audio normalization
yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' \
  --no-playlist \
  -o - "$YT_URL" | \
  ffmpeg -i pipe:0 \
  $TRIM_OPTIONS \
  -c:v mpeg2video -profile:v 0 -level:v 2 -b:v 30M \
  -pix_fmt yuv422p -s 1920x1080 -flags +ilme+ildct -top 1 \
  -aspect 16:9 -r ntsc \
  -c:a pcm_s16le -ar 48000 -ac 2 \
  -af "loudnorm=I=-24:TP=-2:LRA=7:print_format=summary" \
  -f mxf "ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER$FTP_PATH/${OUTPUT_NAME}.mxf"

if [ $? -eq 0 ]; then
  echo "Download, conversion, and upload successful!"
else
  echo "Process failed. Trying alternative method..."
  
  # Alternative method using temporary file
  TMP_FILE="temp_download.mp4"
  
  echo "Downloading to temporary file first..."
  yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' \
    --no-playlist \
    -o "$TMP_FILE" "$YT_URL"
    
  if [ $? -eq 0 ]; then
    echo "Download successful. Converting and uploading..."
    
    ffmpeg -i "$TMP_FILE" \
      $TRIM_OPTIONS \
      -c:v mpeg2video -profile:v 0 -level:v 2 -b:v 30M \
      -pix_fmt yuv422p -s 1920x1080 -flags +ilme+ildct -top 1 \
      -aspect 16:9 -r ntsc \
      -c:a pcm_s16le -ar 48000 -ac 2 \
      -af "loudnorm=I=-24:TP=-2:LRA=7:print_format=summary" \
      -f mxf "ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER$FTP_PATH/${OUTPUT_NAME}.mxf"
      
    # Clean up temp file
    rm "$TMP_FILE"
    
    if [ $? -eq 0 ]; then
      echo "Conversion and upload successful!"
    else
      echo "Conversion and upload failed."
    fi
  else
    echo "Download failed."
  fi
fi