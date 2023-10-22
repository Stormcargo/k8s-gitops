# Paperless management

## User management
If you forget or lose the admin password there are two useful commands to remember.

Get a shell in the main paperless container, and navigate to the `/usr/src/paperless/src` directory. Run `python manage.py <command>` with:
  - `createsuperuser` to create a new admin account and password.
  - `changepassword <username>` to reset the password for a user.

https://docs.djangoproject.com/en/3.2/topics/auth/default/

