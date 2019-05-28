# create a dummy apparixrc file, clobbering it on purpose
# this is NOT how you normally use apparix. Instead you run apparix-init one
# time, and then, do something like
#     $ bm "hello world"
# when you're in the directory of interest
true > "$APPARIXEXPAND"
cat > "$APPARIXRC" <<EOF
j,hello world,$PWD
EOF
echo "set dummy bookmark 'hello world' at $PWD in $APPARIXRC"
