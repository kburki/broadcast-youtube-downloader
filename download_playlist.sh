#!/bin/bash

# YouTube Playlist Downloader
# Downloads playlists in reverse order with systematic renaming

set -e

# Default values
DEFAULT_CODE="SHILS"
DEFAULT_YEAR=$(date +%y)
DEFAULT_START_EPISODE="01"
DEFAULT_START_POSITION="1"
FORCE_OVERWRITE=false
RECODE_TO_MP4=true

# Function to log messages
log_message() {
    local status="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $status: $message" >> activity.log
    echo "[$timestamp] $status: $message"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 PLAYLIST_URL [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  PLAYLIST_URL              YouTube playlist URL"
    echo ""
    echo "Options:"
    echo "  --code CODE               Filename prefix (default: SHILS)"
    echo "  --year YEAR               Two-digit year (default: current year)"
    echo "  --episode NUM             Starting episode number (default: 01)"
    echo "  --start-position NUM      Starting position in playlist (default: 1)"
    echo "  --force                   Overwrite existing files without confirmation"
    echo "  --no-recode               Don't recode to MP4, keep original format"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 'https://youtube.com/playlist?list=...'"
    echo "  $0 'https://youtube.com/playlist?list=...' --code MYSHOW --year 25"
    echo "  $0 'https://youtube.com/playlist?list=...' --episode 05 --start-position 3 --force"
}

# Initialize variables with defaults
PLAYLIST_URL=""
CODE="$DEFAULT_CODE"
YEAR="$DEFAULT_YEAR"
START_EPISODE="$DEFAULT_START_EPISODE"
START_POSITION="$DEFAULT_START_POSITION"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --code)
            CODE="$2"
            shift 2
            ;;
        --year)
            YEAR="$2"
            shift 2
            ;;
        --episode)
            START_EPISODE="$2"
            shift 2
            ;;
        --start-position)
            START_POSITION="$2"
            shift 2
            ;;
        --force)
            FORCE_OVERWRITE=true
            shift
            ;;
        --no-recode)
            RECODE_TO_MP4=false
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$PLAYLIST_URL" ]]; then
                PLAYLIST_URL="$1"
            else
                echo "Unexpected argument: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if playlist URL was provided
if [[ -z "$PLAYLIST_URL" ]]; then
    echo "Error: Playlist URL is required"
    show_usage
    exit 1
fi

# Validate required tools
for tool in yt-dlp jq; do
    if ! command -v "$tool" &> /dev/null; then
        log_message "ERROR" "$tool is required but not installed"
        echo "Please install $tool and try again"
        exit 1
    fi
done

# Check for ffmpeg if recoding is enabled
if [[ "$RECODE_TO_MP4" == true ]] && ! command -v ffmpeg &> /dev/null; then
    log_message "ERROR" "ffmpeg is required for MP4 conversion but not installed"
    echo "Please install ffmpeg or use --no-recode option"
    exit 1
fi

# Validate playlist URL
if [[ ! "$PLAYLIST_URL" =~ youtube\.com.*list= && ! "$PLAYLIST_URL" =~ youtu\.be.*list= ]]; then
    log_message "ERROR" "Invalid YouTube playlist URL: $PLAYLIST_URL"
    echo "Please provide a valid YouTube playlist URL"
    exit 1
fi

# Create output filenames
CSV_FILE="${CODE}_${YEAR}_playlist.csv"

log_message "START" "Beginning playlist download"
log_message "INFO" "Playlist URL: $PLAYLIST_URL"
log_message "INFO" "Code: $CODE, Year: $YEAR, Start Episode: $START_EPISODE, Start Position: $START_POSITION"
log_message "INFO" "Force overwrite: $FORCE_OVERWRITE"
log_message "INFO" "Recode to MP4: $RECODE_TO_MP4"

# Get playlist information
log_message "INFO" "Fetching playlist information..."
if ! PLAYLIST_JSON=$(yt-dlp -j --flat-playlist "$PLAYLIST_URL" 2>/dev/null); then
    log_message "ERROR" "Failed to fetch playlist information"
    echo "Error: Could not fetch playlist information. Please check the URL and your internet connection."
    exit 1
fi

# Parse playlist into array (reverse order for oldest-first)
# Compatible with older bash versions - no mapfile or tac needed
VIDEOS_TEMP=$(echo "$PLAYLIST_JSON" | jq -r '.url')
TITLES_TEMP=$(echo "$PLAYLIST_JSON" | jq -r '.title')

# Reverse the order manually (oldest first)
VIDEOS=()
TITLES=()
while IFS= read -r line; do
    VIDEOS=("$line" "${VIDEOS[@]}")
done <<< "$VIDEOS_TEMP"

while IFS= read -r line; do
    TITLES=("$line" "${TITLES[@]}")
done <<< "$TITLES_TEMP"

TOTAL_VIDEOS=${#VIDEOS[@]}
log_message "INFO" "Found $TOTAL_VIDEOS videos in playlist"

# Calculate which videos to download based on start position
if [[ $START_POSITION -gt $TOTAL_VIDEOS ]]; then
    log_message "ERROR" "Start position ($START_POSITION) exceeds playlist size ($TOTAL_VIDEOS)"
    echo "Error: Start position $START_POSITION is greater than playlist size $TOTAL_VIDEOS"
    exit 1
fi

# Adjust for array indexing (start position is 1-based, array is 0-based)
START_INDEX=$((START_POSITION - 1))
VIDEOS_TO_DOWNLOAD=("${VIDEOS[@]:$START_INDEX}")
TITLES_TO_DOWNLOAD=("${TITLES[@]:$START_INDEX}")

VIDEOS_COUNT=${#VIDEOS_TO_DOWNLOAD[@]}
log_message "INFO" "Will download $VIDEOS_COUNT videos starting from position $START_POSITION"

# Initialize CSV file with headers
echo "original_filename,new_filename,description,air_date" > "$CSV_FILE"
log_message "INFO" "Created CSV file: $CSV_FILE"

# Download and rename videos
CURRENT_EPISODE=$START_EPISODE
SUCCESS_COUNT=0
FAILED_COUNT=0

for i in "${!VIDEOS_TO_DOWNLOAD[@]}"; do
    VIDEO_ID="${VIDEOS_TO_DOWNLOAD[$i]}"
    VIDEO_TITLE="${TITLES_TO_DOWNLOAD[$i]}"
    
    # Handle both video IDs and full URLs
    if [[ "$VIDEO_ID" =~ ^https?:// ]]; then
        # Already a full URL
        VIDEO_URL="$VIDEO_ID"
    else
        # Just a video ID, construct URL
        VIDEO_URL="https://youtube.com/watch?v=${VIDEO_ID}"
    fi
    
    # Format episode number with leading zeros
    EPISODE_NUM=$(printf "%02d" $CURRENT_EPISODE)
    
    # Set file extension based on recode option
    if [[ "$RECODE_TO_MP4" == true ]]; then
        NEW_FILENAME="${CODE}${YEAR}${EPISODE_NUM}.mp4"
    else
        NEW_FILENAME="${CODE}${YEAR}${EPISODE_NUM}.%(ext)s"
    fi
    
    log_message "INFO" "Processing video $((i + 1))/$VIDEOS_COUNT: $VIDEO_TITLE"
    
    # For non-recode mode, we need to determine the actual filename after download
    if [[ "$RECODE_TO_MP4" == false ]]; then
        TEMP_FILENAME="${CODE}${YEAR}${EPISODE_NUM}"
        # Check for existing files with any extension
        EXISTING_FILES=$(ls "${TEMP_FILENAME}".* 2>/dev/null || true)
        if [[ -n "$EXISTING_FILES" && "$FORCE_OVERWRITE" != true ]]; then
            echo "File(s) matching $TEMP_FILENAME.* already exist:"
            echo "$EXISTING_FILES"
            read -p "Overwrite? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_message "SKIP" "Skipped existing file pattern: $TEMP_FILENAME.*"
                ((CURRENT_EPISODE++))
                continue
            fi
        fi
    else
        # Check if MP4 file exists
        if [[ -f "$NEW_FILENAME" && "$FORCE_OVERWRITE" != true ]]; then
            echo "File $NEW_FILENAME already exists."
            read -p "Overwrite? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_message "SKIP" "Skipped existing file: $NEW_FILENAME"
                ((CURRENT_EPISODE++))
                continue
            fi
        fi
    fi
    
    # Get video metadata for CSV
    log_message "INFO" "Fetching metadata for: $VIDEO_TITLE"
    if VIDEO_INFO=$(yt-dlp -j "$VIDEO_URL" 2>/dev/null); then
        ORIGINAL_FILENAME=$(echo "$VIDEO_INFO" | jq -r '.title // "Unknown"' | sed 's/[^a-zA-Z0-9 ._-]//g')
        DESCRIPTION=$(echo "$VIDEO_INFO" | jq -r '.description // "No description"' | head -c 100 | tr '\n' ' ')
        UPLOAD_DATE=$(echo "$VIDEO_INFO" | jq -r '.upload_date // "Unknown"')
        
        # Format upload date
        if [[ "$UPLOAD_DATE" != "Unknown" && ${#UPLOAD_DATE} -eq 8 ]]; then
            FORMATTED_DATE="${UPLOAD_DATE:0:4}-${UPLOAD_DATE:4:2}-${UPLOAD_DATE:6:2}"
        else
            FORMATTED_DATE="Unknown"
        fi
    else
        log_message "WARN" "Could not fetch metadata for video, using defaults"
        ORIGINAL_FILENAME="Unknown"
        DESCRIPTION="Could not fetch description"
        FORMATTED_DATE="Unknown"
    fi
    
    # Download video with appropriate options
    log_message "INFO" "Downloading: $NEW_FILENAME"
    
    if [[ "$RECODE_TO_MP4" == true ]]; then
        # Download and recode to MP4
        echo "  Downloading video $((i + 1))/$VIDEOS_COUNT..."
        if yt-dlp --format "best[height<=1080]" --recode-video mp4 --output "$NEW_FILENAME" "$VIDEO_URL" 2>&1; then
            DOWNLOAD_SUCCESS=true
        else
            DOWNLOAD_SUCCESS=false
        fi
    else
        # Download in original format
        echo "  Downloading video $((i + 1))/$VIDEOS_COUNT..."
        if yt-dlp --format "best[height<=1080]" --output "$NEW_FILENAME" "$VIDEO_URL" 2>&1; then
            DOWNLOAD_SUCCESS=true
        else
            DOWNLOAD_SUCCESS=false
        fi
    fi
    
    if [[ "$DOWNLOAD_SUCCESS" == true ]]; then
        # For non-recode mode, find the actual downloaded filename
        if [[ "$RECODE_TO_MP4" == false ]]; then
            ACTUAL_FILE=$(ls "${CODE}${YEAR}${EPISODE_NUM}".* 2>/dev/null | head -n 1)
            if [[ -n "$ACTUAL_FILE" ]]; then
                NEW_FILENAME="$ACTUAL_FILE"
            fi
        fi
        
        log_message "SUCCESS" "Downloaded: $NEW_FILENAME (Original: $VIDEO_TITLE)"
        ((SUCCESS_COUNT++))
        
        # Add to CSV (escape commas and quotes in fields)
        ESCAPED_ORIGINAL=$(echo "$ORIGINAL_FILENAME" | sed 's/"/""/g')
        ESCAPED_DESCRIPTION=$(echo "$DESCRIPTION" | sed 's/"/""/g')
        echo "\"$ESCAPED_ORIGINAL\",\"$NEW_FILENAME\",\"$ESCAPED_DESCRIPTION\",\"$FORMATTED_DATE\"" >> "$CSV_FILE"
        
    else
        log_message "FAILED" "Failed to download: $NEW_FILENAME (Original: $VIDEO_TITLE)"
        ((FAILED_COUNT++))
        
        # Still add to CSV but mark as failed
        echo "\"FAILED: $ORIGINAL_FILENAME\",\"$NEW_FILENAME\",\"Download failed\",\"$FORMATTED_DATE\"" >> "$CSV_FILE"
    fi
    
    ((CURRENT_EPISODE++))
done

# Final summary
log_message "COMPLETE" "Download process finished"
log_message "SUMMARY" "Total videos processed: $VIDEOS_COUNT"
log_message "SUMMARY" "Successful downloads: $SUCCESS_COUNT"
log_message "SUMMARY" "Failed downloads: $FAILED_COUNT"
log_message "SUMMARY" "CSV log created: $CSV_FILE"

echo ""
echo "Download Summary:"
echo "  Total videos processed: $VIDEOS_COUNT"
echo "  Successful downloads: $SUCCESS_COUNT"
echo "  Failed downloads: $FAILED_COUNT"
echo "  CSV log: $CSV_FILE"
echo "  Activity log: activity.log"
echo ""

if [[ $FAILED_COUNT -gt 0 ]]; then
    echo "Some downloads failed. Check activity.log for details."
    exit 1
else
    echo "All downloads completed successfully!"
    exit 0
fi
