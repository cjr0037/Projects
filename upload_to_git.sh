#!/bin/bash

# Git Upload Script for Master Category Mapping
# Run this script in your local git repository directory

echo "=== Master Category Mapping Git Upload Script ==="
echo "This script will help you add the mapping files to your git repository."
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "Error: Not in a git repository. Please run this script from your git repository root."
    exit 1
fi

echo "Current git repository: $(pwd)"
echo ""

# Files to copy (you'll need to copy these files to your local machine first)
FILES=(
    "Master_Category_Mapping.csv"
    "Mapping_Summary_Report.txt" 
    "Mapping_Validation_Report.md"
    "category_mapper.py"
)

echo "Files to add to git:"
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file (found)"
    else
        echo "✗ $file (missing - please copy this file to your repository)"
    fi
done

echo ""
read -p "Do you want to add these files to git? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Add files to git
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            git add "$file"
            echo "Added: $file"
        fi
    done
    
    # Commit
    echo ""
    read -p "Enter commit message (or press Enter for default): " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="Add master category mapping between Foursquare and Overture Places"
    fi
    
    git commit -m "$commit_msg"
    echo ""
    echo "Files committed successfully!"
    echo ""
    echo "To push to remote repository, run:"
    echo "git push origin main"  # or your branch name
else
    echo "Operation cancelled."
fi