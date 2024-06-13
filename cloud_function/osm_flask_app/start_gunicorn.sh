#!/bin/bash
source venv/bin/activate
exec gunicorn --workers 4 --bind 0.0.0.0:5000 app:app --log-file /var/log/gunicorn.log --log-level debug

