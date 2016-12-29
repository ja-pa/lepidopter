#!/usr/bin/python

import sys
import os
import signal
from BaseHTTPServer import BaseHTTPRequestHandler,HTTPServer

webpage=\
"""<html><head></head><title></title><body>
<center><h1>OONIPROBE is beining updated. Please wait...</h1></center>
</body></html>
"""

class myHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type','text/html')
        self.end_headers()
        self.wfile.write(webpage)
        return

def stop_server(pidfile):
    if os.path.isfile(pidfile):
        pidnum = int(file(pidfile,'r').read().rstrip())
        try:
            os.kill(pidnum, signal.SIGTERM) #or signal.SIGKILL
        except:
            pass
        os.unlink(pidfile)

def start_server(pidfile, port=8080):
    if os.path.isfile(pidfile):
        sys.exit()

    file(pidfile,'w').write(str(os.getpid()))
    server = HTTPServer(('', port), myHandler)
    while True:
        server.handle_request()
    server.socket.close()
    os.unlink(pidfile)

def print_help():
    print "Help:"
    print "start - star webserver"
    print "stop  - stop running webserver"

if __name__ == "__main__":
    if len(sys.argv)>=2:
        filename = os.path.splitext(sys.argv[0])[0]
        filepath = "/tmp/"+filename+".pid"
        if sys.argv[1]=='stop':
           print "Stop server"
           stop_server(filepath) 
        elif sys.argv[1]=='start':
            print "Start server"
            start_server(filepath, 80)
        else:
            print "Not valid argument!"
    else:
        print_help()
