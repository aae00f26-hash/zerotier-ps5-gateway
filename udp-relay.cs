// UDP relay: forward one UDP port on this host to a target host:port (bidirectional, multi-port).
// For PS5 Remote Play over ZeroTier gateway. Compiled to udp-relay.exe for high throughput.
// Usage: udp-relay.exe <targetHost> <port1> [port2 ...]
// Compile: csc.exe /target:exe /out:udp-relay.exe udp-relay.cs
using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;

public static class Program
{
    public static void Main(string[] args)
    {
        if (args.Length < 2) { Console.WriteLine("usage: udp-relay.exe <targetHost> <port1> [port2 ...]"); return; }
        string targetHost = args[0];
        for (int i = 1; i < args.Length; i++)
        {
            int port = int.Parse(args[i]);
            var t = new Thread(() => RelayPort(targetHost, port));
            t.IsBackground = true;
            t.Start();
        }
        Console.WriteLine("relay started: " + (args.Length - 1) + " ports -> " + targetHost);
        Thread.Sleep(Timeout.Infinite);
    }

    static void RelayPort(string targetHost, int localPort)
    {
        UdpClient clientSock = null;
        while (clientSock == null)
        {
            try { clientSock = new UdpClient(new IPEndPoint(IPAddress.Any, localPort)); }
            catch { Thread.Sleep(3000); }
        }
        var targetEP = new IPEndPoint(IPAddress.Parse(targetHost), localPort);
        var targetSock = new UdpClient(0);
        IPEndPoint lastClient = null;
        var lockObj = new object();

        var t1 = new Thread(() =>
        {
            while (true)
            {
                try
                {
                    var remote = new IPEndPoint(IPAddress.Any, 0);
                    byte[] data = clientSock.Receive(ref remote);
                    lock (lockObj) { lastClient = remote; }
                    targetSock.Send(data, data.Length, targetEP);
                }
                catch { Thread.Sleep(10); }
            }
        });
        t1.IsBackground = true;
        t1.Start();

        var t2 = new Thread(() =>
        {
            while (true)
            {
                try
                {
                    var remote = new IPEndPoint(IPAddress.Any, 0);
                    byte[] data = targetSock.Receive(ref remote);
                    IPEndPoint client;
                    lock (lockObj) { client = lastClient; }
                    if (client != null) clientSock.Send(data, data.Length, client);
                }
                catch { Thread.Sleep(10); }
            }
        });
        t2.IsBackground = true;
        t2.Start();
    }
}
