## Session Progress

- [x] Added a health status report task 'health' in justfile that prints a health report for each compose.yml in the stacks directory by checking docker-compose config.
- [x] Added a tasks section to README.md that lists available tasks.
- [x] Fixed bug in health task by using bash instead of sh so that the read command's -d option works correctly. 