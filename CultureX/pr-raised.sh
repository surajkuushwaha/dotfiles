#!/bin/bash

# --- Configuration ---
# Set the base branch you want the PR to merge into 
BASE_BRANCH="testing" 
# Set the title for your new Pull Request
PR_TITLE="TEST PR - Testing deployment hook for $(date +%d/%m)"
# The remote to use for the target repository slug (CultureX-art/repo-name)
TARGET_REMOTE="upstream"

# --- Script Logic ---

echo "Starting the Branch and PR creation process..."
echo "---"

# 1. Dynamically determine the repository slug (owner/repo) from the TARGET_REMOTE
REMOTE_URL=$(git config --get remote."$TARGET_REMOTE".url)

if [ -z "$REMOTE_URL" ]; then
    echo "❌ Error: Could not find remote '$TARGET_REMOTE'. Please ensure 'git remote -v' shows an '$TARGET_REMOTE' entry."
    exit 1
fi

# Parsing logic: Extracts 'CultureX-art/cx-worker' from the upstream URL
TARGET_REPO_SLUG=$(echo "$REMOTE_URL" | sed -E 's/.*:([^/]+\/[^/]+)\.git$/\1/')

if [[ -z "$TARGET_REPO_SLUG" || ! "$TARGET_REPO_SLUG" == *"/"* ]]; then
    echo "❌ Error: Failed to determine the repository slug (owner/repo) from $TARGET_REMOTE URL: $REMOTE_URL"
    exit 1
fi

echo "Target Repository Slug (Base Repo): **$TARGET_REPO_SLUG**"
echo "---"

# 2. Get the current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current Branch: **$CURRENT_BRANCH**"

# 3. Format the date as DD-MM
DATE_SUFFIX=$(date +%d-%m)

# 4. Create the new branch name in the format: <current-branch-name>-testing-<DD-MM>
NEW_BRANCH_NAME="${CURRENT_BRANCH}-testing-${DATE_SUFFIX}"
NEW_BRANCH_NAME=$(echo "$NEW_BRANCH_NAME" | tr -c '[:alnum:]-\n' '-')

echo "New Branch Name (Head Branch): **$NEW_BRANCH_NAME**"
echo "---"

# 5. Create and check out the new branch
if ! git checkout -b "$NEW_BRANCH_NAME"; then
    echo "❌ Error: Could not create and checkout the new branch. It might already exist locally."
    exit 1
fi

echo "✅ Switched to new branch: **$NEW_BRANCH_NAME**"

# 6. FIX: Add a dummy commit to ensure the new branch has unique history for the PR
MARKER_FILE=".pr_test_marker_$(date +%s)"
echo "TEST COMMIT - Raised PR for staging on $NEW_BRANCH_NAME" > "$MARKER_FILE"
git add "$MARKER_FILE"

if ! git commit -m "chore(testing): Add marker for automated PR to $BASE_BRANCH on $DATE_SUFFIX"; then
    echo "❌ Error: Failed to create the dummy commit."
    # Attempt to clean up the branch locally before exiting
    git checkout "$CURRENT_BRANCH"
    git branch -D "$NEW_BRANCH_NAME"
    rm "$MARKER_FILE" 2>/dev/null
    exit 1
fi
rm "$MARKER_FILE" 2>/dev/null # Clean up the file after committing
echo "✅ Dummy commit created to ensure unique history."
echo "---"

# 7. Push the new branch to the remote 'origin' (your fork)
echo "Pushing **$NEW_BRANCH_NAME** to **origin**..."
if ! git push -u origin "$NEW_BRANCH_NAME"; then
    echo "❌ Error: Could not push the new branch to origin."
    exit 1
fi

echo "✅ Branch pushed successfully."
echo "---"

# 8. Create the Pull Request using 'gh'
echo "Creating Pull Request on **$TARGET_REPO_SLUG**"
echo "Targeting base branch: **$BASE_BRANCH**"

PR_URL=$(gh pr create \
    --title "$PR_TITLE" \
    --body "**TEST PR** - Created dynamically for staging/deployment testing from $CURRENT_BRANCH. Target base: $BASE_BRANCH" \
    --base "$BASE_BRANCH" ) 

if [ $? -eq 0 ]; then
    echo "🎉 **SUCCESS! Pull Request created.**"
    echo "🔗 **PR URL:** $PR_URL"
else
    echo "❌ Error: Could not create the Pull Request with 'gh pr create'."
    echo "Please ensure the **$BASE_BRANCH** branch exists in the **$TARGET_REPO_SLUG** repository."
fi