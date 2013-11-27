#!/bin/sh

carton exec -- perl set_hook.pl
exec carton exec -- perl app.pl
