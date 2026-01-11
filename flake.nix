{
    inputs = { } ;
    outputs =
        { self } :
            {
                lib =
                    { failure , pkgs } :
                        let
                            implementation =
                                {
                                    channel ,
                                    log-directory ,
                                    log-file ,
                                    log-lock
                                } :
                                    let
                                        application =
                                            pkgs.writeShellApplication
                                                {
                                                    name = "resource-logger" ;
                                                    runtimeInputs =
                                                        [
                                                            pkgs.coreutils
                                                            pkgs.flock
                                                            pkgs.jq
                                                            pkgs.redis
                                                            pkgs.yq-go
                                                            failure
                                                            (
                                                                pkgs.writeShellApplication
                                                                    {
                                                                        name = "iteration" ;
                                                                        runtimeInputs = [ pkgs.coreutils pkgs.flock ] ;
                                                                        text =
                                                                            ''
                                                                                CHANNEL="$1"
                                                                                PAYLOAD="$2"
                                                                                TIMESTAMP="$( date +%s )" || failure dc03876c
                                                                                TEMPORARY="$( mktemp )" || failure c073c0f8
                                                                                jq --arg TIMESTAMP "$TIMESTAMP" --arg CHANNEL "$CHANNEL" '{ "channel" : $CHANNEL , "payload" : . , "timestamp" : $TIMESTAMP }' <<< "$PAYLOAD" > "$TEMPORARY"
                                                                                mkdir --parents ${ log-directory }
                                                                                exec 203> ${ log-directory }/${ log-lock }
                                                                                flock 203
                                                                                yq eval --prettyPrint '[.]' "$TEMPORARY" >> ${ log-directory }/${ log-file }
                                                                                rm "$TEMPORARY"
                                                                            '' ;
                                                                    }
                                                            )
                                                        ] ;
                                                    text =
                                                        ''
                                                            redis-cli SUBSCRIBE "${ channel }" | while true
                                                            do
                                                                read -r TYPE || failure c5aa2fb4
                                                                read -r CHANNEL || failure 9c77b920
                                                                read -r PAYLOAD || failure 3b7888f3
                                                                if [[ "message" == "$TYPE" ]]
                                                                then
                                                                    iteration "$CHANNEL" "$PAYLOAD" &
                                                                fi
                                                            done
                                                        '' ;
                                                } ;
                                        in "${ application }/bin/resource-logger" ;
                            in
                                {
                                    check =
                                        {
                                            channel ? "8abec172" ,
                                            expected ,
                                            log-directory ? "bc20f63b" ,
                                            log-file ? "2555b21b" ,
                                            log-lock ? "b07f0f0a" ,
                                        } :
                                            pkgs.stdenv.mkDerivation
                                                {
                                                    installPhase = ''execute-test "$out"'' ;
                                                    name = "check" ;
                                                    nativeBuildInputs =
                                                        [
                                                            (
                                                                let
                                                                    observed = builtins.toString ( implementation { channel = channel ; log-directory = log-directory ; log-file = log-file ; log-lock = log-lock ; } ) ;
                                                                    in
                                                                        if expected == observed then
                                                                           pkgs.writeShellApplication
                                                                                {
                                                                                    name = "execute-test" ;
                                                                                    runtimeInputs = [ pkgs.coreutils ] ;
                                                                                    text =
                                                                                        ''
                                                                                            OUT="$1"
                                                                                            touch "$OUT"
                                                                                        '' ;
                                                                                }
                                                                        else
                                                                            pkgs.writeShellApplication
                                                                                {
                                                                                    name = "execute-test" ;
                                                                                    runtimeInputs = [ pkgs.coreutils failure ] ;
                                                                                    text =
                                                                                        ''
                                                                                            OUT="$1"
                                                                                            touch "$OUT"
                                                                                            failure a4f6643f "We expected ${ expected } but observed ${ observed }"
                                                                                        '' ;
                                                                                }
                                                            )
                                                        ] ;
                                                    src = ./. ;
                                                } ;
                                    implementation = implementation ;
                                } ;
            } ;
}