# Git Workflow for TikTok Lite Automation

## Critical Version Control Rule

**All Git operations that modify the repository (especially commits and pushes) must ONLY be performed when explicitly instructed by the user.**

## Standard Workflow

1. **Code Changes**
   - Make changes to code files as instructed by user
   - Test changes when appropriate
   - Show diffs or summaries of changes upon completion

2. **Staging Changes**
   - When changes are ready for commit, use `git add` to stage them
   - Always show the status of staged changes using `git status`
   - Wait for explicit confirmation to proceed

3. **Commit Process**
   - **ONLY** commit changes when explicitly instructed with phrases like:
     - "Commit these changes"
     - "Make a commit now"
     - "Commit with message [message]"
   - Use descriptive commit messages that explain the changes
   - Push only when specifically instructed with phrases like:
     - "Push to repository"
     - "Push these changes"
     - "Push to [branch]"

## User Confirmation Required For

- Creating/switching branches
- Committing changes
- Pushing to repository
- Pulling from repository
- Merging branches
- Rebasing
- Resetting to previous commits
- Any operation that modifies repository history

## Example Workflow

```
User: "Make these changes to file X..."
Assistant: [Makes changes]
Assistant: "Changes complete. Here's what was modified: [summary]"

User: "Stage these changes"
Assistant: [Uses git add]
Assistant: "Changes staged. Current status: [git status output]"

User: "Commit these changes with message 'Fix bug in X function'"
Assistant: [Now commits with the specified message]
Assistant: "Changes committed with message 'Fix bug in X function'"

User: "Push to develop branch"
Assistant: [Only now pushes to the develop branch]
```

## Important Notes

- If you're unsure whether a Git operation is requested, ask for clarification
- Always show the current status before and after Git operations
- For significant operations (like force pushes), always ask for confirmation even if instructed
- When instructed to commit, suggest an appropriate commit message if one isn't provided, but wait for approval

## Repository Structure

- `develop` - Primary development branch
- Feature branches should be created for major changes
- Deployment process is handled separately 