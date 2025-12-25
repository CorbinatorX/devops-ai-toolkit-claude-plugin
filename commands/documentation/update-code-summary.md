# Update Code Summary Command

You are tasked with updating the repository code statistics in `code-summary.md` at the repository root.

## Instructions

1. **Run cloc analysis**:
   - Execute: `cloc . --exclude-dir=node_modules,bin,obj,.next,dist,build,.expo,.git --exclude-ext=xml --quiet`
   - This provides the main summary statistics

2. **Update code-summary.md**:
   - Update the "Generated" date to today's date
   - Update the "Total Lines of Code" section with new totals
   - Update the "Breakdown by Language" table with current statistics
   - Recalculate all percentages based on new totals
   - Update the "Code Quality Metrics" section:
     - Comment Density
     - Documentation Ratio
     - Average File Size
   - Update the "Key Statistics" section with new file counts

3. **Preserve structure**:
   - Keep the same markdown structure and sections
   - Maintain the formatting and table layouts
   - Keep the "Repository Structure", "Technology Stack Summary", and "Analysis Method" sections unchanged unless there are significant changes

4. **Output**:
   - Show a summary of the changes (old vs new line counts)
   - Confirm the file has been updated

## Expected Behavior

- The command should be fully automated
- No user input required
- Complete the update in a single operation
- Report any significant changes in LOC (>5% increase/decrease)

## Notes

- Exclude XML files to avoid inflating counts with test coverage reports
- Focus on source code files (C#, TypeScript, JavaScript, etc.)
- Maintain consistency with previous cloc runs
