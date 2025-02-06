#!/bin/sh

echo "Starting dotnet-format.sh script"

# Check if current commit is a merge commit
echo "\nChecking if current commit is a merge commit"
if git rev-parse --verify HEAD^2 > /dev/null 2>&1; then
    echo "Current commit is a merge commit, skipping format"
    exit 0
fi

# Get base SHA from environment variable
BASE_SHA=$PR_BASE_SHA
if [ -z "$BASE_SHA" ]; then
    echo "PR_BASE_SHA environment variable not set"
    exit 1
fi

# Get changed .cs files between PR base and current HEAD
echo "\nGetting changed .cs files between $BASE_SHA and HEAD"
# Create a temporary file for storing file list
FILES_LIST=$(mktemp)
trap 'rm -f $FILES_LIST' EXIT

# Store files in temporary file to preserve spaces
git diff --name-only -z $BASE_SHA | tr '\0' '\n' | grep '\.cs$' > "$FILES_LIST" || true

if [ ! -s "$FILES_LIST" ]; then
    echo "No .cs files were changed in this PR"
    exit 0
fi

echo "\nChanged .cs files:"
cat "$FILES_LIST"

# Create a temporary file to store project-file mappings
echo "\nCreating temporary file for project mappings"
TEMP_FILE=$(mktemp)
echo "Temporary file created at: $TEMP_FILE"
trap 'rm -f $TEMP_FILE $FILES_LIST' EXIT

# Function to find the closest .csproj file for a given file
find_closest_csproj() {
    FILE_PATH="$1"
    DIR=$(dirname "$FILE_PATH")
    while [ "$DIR" != "/" ]; do
        CS_PROJ=$(find "$DIR" -maxdepth 1 -name "*.csproj" | head -n 1)
        if [ -n "$CS_PROJ" ]; then
            printf '%s' "$CS_PROJ"
            return
        fi
        DIR=$(dirname "$DIR")
    done
}

# Group files by their closest .csproj
echo "\nGrouping files by their closest .csproj"
while IFS= read -r FILE; do
    [ -z "$FILE" ] && continue
    
    echo "\nProcessing file: $FILE"
    PROJECT_FILE=$(find_closest_csproj "$FILE")
    if [ -n "$PROJECT_FILE" ]; then
        echo "Adding to mapping: $PROJECT_FILE -> $FILE"
        printf '%s:%s\n' "$PROJECT_FILE" "$FILE" >> "$TEMP_FILE"
    else
        echo "No project file found for $FILE. Skipping."
    fi
done < "$FILES_LIST"

# Get unique project files
echo "\nGetting unique project files"
PROJECT_LIST=$(mktemp)
trap 'rm -f $TEMP_FILE $FILES_LIST $PROJECT_LIST' EXIT
cut -d: -f1 "$TEMP_FILE" | sort -u > "$PROJECT_LIST"

echo "Found projects:"
cat "$PROJECT_LIST"

# Process each project
while IFS= read -r PROJECT; do
    [ -z "$PROJECT" ] && continue
    
    echo "\nProcessing project: $PROJECT"
    
    # Create a temporary file for the include list
    INCLUDE_LIST=$(mktemp)
    trap 'rm -f $TEMP_FILE $FILES_LIST $PROJECT_LIST $INCLUDE_LIST' EXIT
    
    # Get all files for this project
    grep "^$PROJECT:" "$TEMP_FILE" | cut -d: -f2- > "$INCLUDE_LIST"
    
    echo "Files to format in this project:"
    cat "$INCLUDE_LIST"
    
    echo "\nRunning dotnet format for project $PROJECT"
    
    # Build the dotnet format command with proper quoting
    CMD="dotnet format \"$PROJECT\" --diagnostics IDE0005 --severity info --include"
    while IFS= read -r FILE; do
        CMD="$CMD \"$FILE\""
    done < "$INCLUDE_LIST"
    
    echo "Command: $CMD"
    eval "$CMD" || {
        echo "Warning: dotnet format command failed with exit code $?, continuing..."
    }

    # Stage the formatted files
    echo "\nStaging formatted files"
    while IFS= read -r FILE; do
        echo "Staging file: $FILE"
        git add "$FILE"
    done < "$INCLUDE_LIST"
    
    rm -f "$INCLUDE_LIST"
done < "$PROJECT_LIST"

rm -f "$PROJECT_LIST"
rm -f "$FILES_LIST"
rm -f "$TEMP_FILE"

echo "\nScript completed successfully"