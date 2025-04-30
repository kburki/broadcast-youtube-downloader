#!/bin/bash

# YouTube Video Downloader, Converter, and FTP Uploader
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

# Check if required arguments are provided
if [ $# -lt 2 ]; then
  echo "Usage: $0 youtube_url output_name"
  echo "Example: $0 'https://www.youtube.com/watch?v=abcdefghijk' 'SHILS_001'"
  exit 1
fi

# Get input arguments
YT_URL="$1"
OUTPUT_NAME="$2"

echo "Downloading, converting, and uploading to FTP server in one step..."
echo "Video URL: $YT_URL"
echo "Output filename: $OUTPUT_NAME.mxf"

# Using yt-dlp to download and pipe to ffmpeg for conversion and direct upload with audio normalization
yt-dlp -f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]' \
  --no-playlist \
  -o - "$YT_URL" | \
  ffmpeg -i pipe:0 \
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
