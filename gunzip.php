#!/mnt/syb8634/server/php
<?php
#
# For platforms without gunzip 
# Using redirection may add an extra blank line.
# gzpassthru and readgz file dont seem to handle last line correctly
# when using re-direction??
# 
#                       Alord/Ydrol
#
function gunzip($filename,$out) {
    $file = @gzopen($filename, 'rb');
    if ($file) {
        while (!gzeof($file)) {
            $data = gzread($file, 10240);
            if ($data != "") {
                fwrite($out,$data);
            }
        }
        gzclose($file);
    }
}

$in="php://stdin";
$out="php://stdout";
if ($argc == 1 ) {
    print "usage:php $argv[0] input output\n";
    print "A dash means use stdin .\n";
    print "eg cat file | /mnt/syb8634/server/php $argv[0] - out.txt\n";
    print "Sending to stdout implemented but not yet supported. slight corruption of output";
    exit(1);
}

if ($argc >= 1 && $argv[1] != "-" ) {
    $in=$argv[1];
}

if ($argc >= 2 && $argv[2] != "-" ) {
    $out=$argv[2];
}

#readgzfile($in);
$out=fopen($out,"wb");
gunzip($in,$out);

if ($out != STDERR) {
    fclose($out);
}


?>

