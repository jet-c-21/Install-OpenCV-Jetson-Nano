#!/bin/bash

start_time=$(date +%s) # be careful +%s should separate with data



end_time=$(date +%s)
diff_time=$((end_time - start_time))
hours=$((diff_time / 3600))
minutes=$(((diff_time % 3600) / 60))
seconds=$((diff_time % 60))
printf "Build time: %02d:%02d:%02d\n" $hours $minutes $seconds
