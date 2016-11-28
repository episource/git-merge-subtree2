SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"

for test in $(ls $SCRIPT_DIR); do
    [[ "$test" == *"$( basename $0 )" ]] && continue
    
    >&2 echo -n "TEST: $test... "
    "$SCRIPT_DIR/$test" 2>/dev/null >/dev/null && echo "PASSED" || echo "FAILED"
done