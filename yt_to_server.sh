#!/bin/bash

# YouTube Video Downloader, Converter, and FTP Uploader with Trimming
# This script processes a single YouTube video, converting it to MXF or MP4 format

# Load credentials from hidden file if uploading to FTP
if [ -f ~/.ftp_credentials ]; then
  source ~/.ftp_credentials
fi

# Default parameters
TRIM_START="0"       # Default: no trimming from start
OUT_POINT=""         # Default: no specific out point
OUTPUT_FORMAT="mxf"  # Default: MXF format
LOCAL_OUTPUT_DIR="./OUT" # Default local output directory for MP4 files

# Function to show usage information
show_usage() {
  echo "Usage: $0 [options] youtube_url output_name"
  echo "Options:"
  echo "  -t, --trim-start TIME    Trim from start of video (format: HH:MM:SS or seconds)"
  echo "  -o, --out-point TIME     Specify out point/end time (format: HH:MM:SS)"
  echo "  -f, --format FORMAT      Output format: mxf or mp4 (default: mxf)"
  echo "  -d, --directory DIR      Local output directory for MP4 files (default: ./OUT)"
  echo "  -h, --help               Show this help message"
  echo
  echo "Examples:"
  echo "  $0 -t 00:01:30 -o 00:45:20 'https://www.youtube.com/watch?v=VIDEO_ID' 'SHILS_001'"
  echo "  $0 -f mp4 'https://www.youtube.com/watch?v=VIDEO_ID' 'SHILS_001'"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
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
    -d|--directory)
      LOCAL_OUTPUT_DIR="$2"
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

echo "Downloading and converting video..."
echo "Video URL: $YT_URL"
echo "Output format: $OUTPUT_FORMAT"
if [ "$OUTPUT_FORMAT" = "mp4" ]; then
  echo "Output will be saved locally to: $LOCAL_OUTPUT_DIR/$OUTPUT_NAME.$OUTPUT_FORMAT"
else
  echo "Output will be uploaded to FTP server as: $OUTPUT_NAME.$OUTPUT_FORMAT"
fi

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

# Prepare the ffmpeg options for trimming
TRIM_OPTIONS=""

if [ "$TRIM_START" != "0" ]; then
  echo "Trimming $TRIM_START from the beginning of the video"
  TRIM_OPTIONS="$TRIM_OPTIONS -ss $TRIM_START"
fi

if [ -n "$OUT_POINT" ]; then
  echo "Setting out point to $OUT_POINT"
  
  # If trim start is specified, calculate duration
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

# Ensure output directory exists for MP4 output
if [ "$OUTPUT_FORMAT" = "mp4" ]; then
  mkdir -p "$LOCAL_OUTPUT_DIR"
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
  OUTPUT_PATH="\"ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER$FTP_PATH/${OUTPUT_NAME}.mxf\""
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
  OUTPUT_PATH="\"$LOCAL_OUTPUT_DIR/${OUTPUT_NAME}.mp4\""
fi

# Download and convert
if [ "$OUTPUT_FORMAT" = "mp4" ] || [ -n "$FTP_SERVER" ]; then
  # Try direct conversion
  echo "Downloading and converting..."
  
  # Build the ffmpeg command
  FFMPEG_CMD="yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' --no-playlist -o - \"$YT_URL\" | \
    ffmpeg -i pipe:0 $TRIM_OPTIONS $OUTPUT_SETTINGS $OUTPUT_PATH"
  
  # Execute the command
  eval $FFMPEG_CMD
  
  if [ $? -eq 0 ]; then
    echo "Download and conversion successful!"
    if [ "$OUTPUT_FORMAT" = "mp4" ]; then
      echo "File saved to: $LOCAL_OUTPUT_DIR/${OUTPUT_NAME}.mp4"
    else
      echo "File uploaded to server as: ${OUTPUT_NAME}.mxf"
    fi
  else
    echo "Process failed. Trying alternative method..."
    
    # Alternative method using temporary file
    TMP_FILE="temp_download.mp4"
    
    echo "Downloading to temporary file first..."
    yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' --no-playlist -o "$TMP_FILE" "$YT_URL"
      
    if [ $? -eq 0 ]; then
      echo "Download successful. Converting..."
      
      # Build and execute ffmpeg command
      FFMPEG_CMD="ffmpeg -i \"$TMP_FILE\" $TRIM_OPTIONS $OUTPUT_SETTINGS $OUTPUT_PATH"
      eval $FFMPEG_CMD
      
      # Clean up temp file
      rm "$TMP_FILE"
      
      if [ $? -eq 0 ]; then
        echo "Conversion successful!"
        if [ "$OUTPUT_FORMAT" = "mp4" ]; then
          echo "File saved to: $LOCAL_OUTPUT_DIR/${OUTPUT_NAME}.mp4"
        else
          echo "File uploaded to server as: ${OUTPUT_NAME}.mxf"
        fi
      else
        echo "Conversion failed."
      fi
    else
      echo "Download failed."
    fi
  fi
else
  echo "Error: FTP credentials are required for MXF output. Please create ~/.ftp_credentials or use MP4 output."
  exit 1
fi