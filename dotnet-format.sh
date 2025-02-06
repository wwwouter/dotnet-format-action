#!/bin/sh
# dotnet format needs a project file to run. This code groups the files by their closest .csproj file and runs dotnet format for each project.

# Create a temporary file to store project-file mappings
TEMP_FILE=$(mktemp)
trap 'rm -f $TEMP_FILE' EXIT

# Function to find the closest .csproj file for a given file
find_closest_csproj() {
    FILE_PATH="$1"
    DIR=$(dirname "$FILE_PATH")
    while [ "$DIR" != "/" ]; do
        CS_PROJ=$(find "$DIR" -maxdepth 1 -name "*.csproj" | head -n 1)
        if [ -n "$CS_PROJ" ]; then
            echo "$CS_PROJ"
            return
        fi
        DIR=$(dirname "$DIR")
    done
    echo ""
}

# Group files by their closest .csproj
for FILE in $STAGED_FILES; do
    PROJECT_FILE=$(find_closest_csproj "$FILE")
    if [ -n "$PROJECT_FILE" ]; then
        echo "$PROJECT_FILE:$FILE" >> "$TEMP_FILE"
    else
        echo "No project file found for $FILE. Skipping."
    fi
done

# Get unique project files
PROJECTS=$(cut -d: -f1 "$TEMP_FILE" | sort -u)

# Process each project
for PROJECT in $PROJECTS; do
    # Get all files for this project
    FILES=$(grep "^$PROJECT:" "$TEMP_FILE" | cut -d: -f2- | tr '\n' ' ')
    
    echo "Running dotnet format for project $PROJECT on files: $FILES"
    dotnet format "$PROJECT" --diagnostics IDE0005 --severity info --include $FILES || true

    # Stage the formatted files
    for FILE in $FILES; do
        git add "$FILE"
    done
done
