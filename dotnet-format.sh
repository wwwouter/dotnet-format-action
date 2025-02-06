#!/bin/sh

echo "Starting dotnet-format.sh script"

# Check if current commit is a merge commit
echo "\nChecking if current commit is a merge commit"
if git rev-parse --verify HEAD^2 > /dev/null 2>&1; then
    echo "Current commit is a merge commit, skipping format"
    exit 0
fi

# Get changed .cs files between current and previous commit
echo "\nGetting changed .cs files between HEAD and HEAD~1"
STAGED_FILES=$(git diff --name-only HEAD~1 | grep '\.cs$' || true)

if [ -z "$STAGED_FILES" ]; then
    echo "No .cs files were changed in the last commit"
    exit 0
fi

echo "\nChanged .cs files:"
echo "$STAGED_FILES"

# Create a temporary file to store project-file mappings
echo "\nCreating temporary file for project mappings"
TEMP_FILE=$(mktemp)
echo "Temporary file created at: $TEMP_FILE"
trap 'rm -f $TEMP_FILE' EXIT

# Function to find the closest .csproj file for a given file
find_closest_csproj() {
    FILE_PATH="$1"
    echo "\nFinding closest .csproj for: $FILE_PATH"
    DIR=$(dirname "$FILE_PATH")
    while [ "$DIR" != "/" ]; do
        echo "Searching in directory: $DIR"
        CS_PROJ=$(find "$DIR" -maxdepth 1 -name "*.csproj" | head -n 1)
        if [ -n "$CS_PROJ" ]; then
            echo "Found project file: $CS_PROJ"
            echo "$CS_PROJ"
            return
        fi
        DIR=$(dirname "$DIR")
    done
    echo "No project file found"
    echo ""
}

# Group files by their closest .csproj
echo "\nGrouping files by their closest .csproj"
for FILE in $STAGED_FILES; do
    echo "\nProcessing file: $FILE"
    PROJECT_FILE=$(find_closest_csproj "$FILE")
    if [ -n "$PROJECT_FILE" ]; then
        echo "Adding to mapping: $PROJECT_FILE -> $FILE"
        echo "$PROJECT_FILE:$FILE" >> "$TEMP_FILE"
    else
        echo "No project file found for $FILE. Skipping."
    fi
done

# Get unique project files
echo "\nGetting unique project files"
PROJECTS=$(cut -d: -f1 "$TEMP_FILE" | sort -u)
echo "Found projects:"
echo "$PROJECTS"

# Process each project
for PROJECT in $PROJECTS; do
    echo "\nProcessing project: $PROJECT"
    
    # Get all files for this project
    FILES=$(grep "^$PROJECT:" "$TEMP_FILE" | cut -d: -f2- | tr '\n' ' ')
    echo "Files to format in this project:"
    echo "$FILES"
    
    echo "\nRunning dotnet format for project $PROJECT"
    echo "Command: dotnet format \"$PROJECT\" --diagnostics IDE0005 --severity info --include $FILES"
    dotnet format "$PROJECT" --diagnostics IDE0005 --severity info --include $FILES || {
        echo "Warning: dotnet format command failed with exit code $?, continuing..."
    }

    # Stage the formatted files
    echo "\nStaging formatted files"
    for FILE in $FILES; do
        echo "Staging file: $FILE"
        git add "$FILE"
    done
done

echo "\nScript completed successfully"
