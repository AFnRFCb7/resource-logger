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
                                    description ,
                                    enable ,
                                    log-directory ,
                                    log-file ,
                                    log-lock ,
                                    user
                                } :
                                    {
                                        service =
                                            {
                                                after = [ "network.target" "redis.service" ] ;
                                                description = description ;
                                                enable = enable ;
                                                serviceConfig =
                                                    {
                                                        ExecStart =
                                                            let
                                                                application =
                                                                    pkgs.writeShellApplication
                                                                        {
                                                                            name = "ExecStart" ;
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
                                                                in "${ application }/bin/ExecStart" ;
                                                        User = user ;
                                                    } ;
                                                wantedBy = [ "multiuser.target" ] ;
                                            } ;
                                    } ;
                            in
                                {
                                    check =
                                        {
                                            channel ? "8abec172" ,
                                            description ? "ac44acef" ,
                                            enable ? "e7df307f" ,
                                            expected ,
                                            log-directory ? "bc20f63b" ,
                                            log-file ? "2555b21b" ,
                                            log-lock ? "b07f0f0a" ,
                                            user ? "a2ce8612"
                                        } :
                                            pkgs.stdenv.mkDerivation
                                                {
                                                    installPhase = ''execute-test "$out"'' ;
                                                    name = "check" ;
                                                    nativeBuildInputs =
                                                        [
                                                            (
                                                                let
                                                                    observed =
                                                                        implementation
                                                                            {
                                                                                channel = channel ;
                                                                                description = description ;
                                                                                expected = expected ;
                                                                                enable = enable ;
                                                                                log-directory = log-directory ;
                                                                                log-file = log-file ;
                                                                                log-lock = log-lock ;
                                                                                user = user ;
                                                                            } ;
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
                                                                                            failure a4f6643f "We expected expected to be observed" "EXPECTED=${ builtins.toFile "expected.json" ( builtins.toJSON expected ) }" "OBSERVED=${ builtins.toFile "observed.json" ( builtins.toJSON observed ) }"
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