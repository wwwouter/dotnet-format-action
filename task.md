I want to create a C# project to test a github action.

It should only `dotnet format` the changes files (see dotnet-format.sh).

Only IDE0005 should be fixed. (see dotnet-format.sh)

It should use this action:
```
   - name: Commit formatted changes
        uses: EndBug/add-and-commit@v9
        with:
          author_name: 'GitHub Action'
          author_email: 'action@github.com'
          message: 'Apply dotnet format formatting'
          add: '.'
```


Tasks
- create project
- create class with unused using
- create github action
