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
                                    channel ? "redis" ,
                                    log-directory ,
                                    log-file ? "log.yaml" ,
                                    log-lock ? "log.lock" ,
                                } :
                                    let
                                        application =
                                            pkgs.writeShellApplication
                                                {
                                                    name = "implementation" ;
                                                    runtimeInputs =
                                                        [
                                                            pkgs.coreutils
                                                            pkgs.redis
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
                                        in "${ application }/bin/implementation" ;
                            in
                                {
                                    check =
                                        {
                                            channel ? "redis" ,
                                            expected ,
                                            log-directory ,
                                            log-file ? "log.yaml" ,
                                            log-lock ? "log.lock"
                                        } :
                                            pkgs.stdenv.mkDerivation
                                                {
                                                    installPhase = ''execute-test "$out"'' ;
                                                    name = "check" ;
                                                    nativeBuildInputs =
                                                        [
                                                            (
                                                                pkgs.writeShellApplication
                                                                    {
                                                                        name = "execute-test" ;
                                                                        runtimeInputs = [ pkgs.coreutils pkgs.diffutils ] ;
                                                                        text =
                                                                            let
                                                                                expected-file = builtins.toFile "expected" expected ;
                                                                                observed-file =
                                                                                    implementation
                                                                                        {
                                                                                            channel = channel ;
                                                                                            log-directory = log-directory ;
                                                                                            log-file = log-file ;
                                                                                            log-lock = log-lock ;
                                                                                        } ;
                                                                            in
                                                                                if builtins.readFile expected == observed then
                                                                                    ''
                                                                                        OUT="$1"
                                                                                        touch "$OUT"
                                                                                    ''
                                                                                else
                                                                                    ''
                                                                                        OUT="$1"
                                                                                        touch "$OUT"
                                                                                        echo EXPECTED
                                                                                        echo ${ expected-file }
                                                                                        echo
                                                                                        echo OBSERVED
                                                                                        echo ${ observed-file }
                                                                                        echo
                                                                                        diff --unified ${ expected-file } ${ observed-file }
                                                                                        failure a4f6643f
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