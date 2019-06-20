# create a dummy apparixrc file, clobbering it on purpose
# this is NOT how you normally use apparix. Instead you run something like
#     $ bm hworld
# when you're in the directory of interest
true > "$APPARIXEXPAND"
cat > "$APPARIXRC" <<EOF
j,hworld,$PWD
EOF
echo "set dummy bookmark 'hworld' at $PWD in $APPARIXRC"
