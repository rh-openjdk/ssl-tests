import java.io.InputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.FileSystems;
import java.util.Map;
import java.util.HashMap;
import java.util.concurrent.Callable;

public class SysDepsProps implements Callable<Map<String, String>> {

    Thread streamDiscarder(final InputStream is) {
        return new Thread() {
            @Override
            public void run() {
                try {
                    try {
                        while (is.read() >= 0) { /* discard */ };
                    } finally {
                        is.close();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        };
    }

    boolean checkOnPath(String cmd) {
        ProcessBuilder pb = new  ProcessBuilder(cmd, "--help");
        Process p = null;
        Thread outDiscarder = null;
        Thread errDiscarder = null;
        int retVal = 0;
        try {
            p = pb.start(); // throws exception if program does not exist
            outDiscarder = streamDiscarder(p.getInputStream());
            outDiscarder.start();
            errDiscarder = streamDiscarder(p.getErrorStream());
            errDiscarder.start();
            p.getOutputStream().close();
            p.waitFor();
            return true;
        } catch (Exception ex) {
            if (p != null) {
                p.destroy();
            }
        } finally {
            try {
                if (outDiscarder != null) {
                    outDiscarder.join();
                }
                if (errDiscarder != null) {
                    errDiscarder.join();
                }
            } catch (InterruptedException ex) {}
        }
        return false;
    }

    boolean fileExists(String path) {
        return Files.exists(FileSystems.getDefault().getPath(path));
    }

    boolean checkGnutlsCli() {
        return checkOnPath("gnutls-cli");
    }

    boolean checkTstclnt() {
        if (fileExists("/usr/lib64/nss/unsupported-tools/tstclnt")
            || fileExists("/usr/lib/nss/unsupported-tools/tstclnt")) {
            return true;
        }
        return checkOnPath("tstclnt");
    }

    @Override
    public Map<String, String> call() {
        Map<String, String> map = new HashMap<String, String>();
        map.put("bin.gnutlscli", checkGnutlsCli() ? "true": "false");
        map.put("bin.tstclnt", checkTstclnt() ? "true": "false");
        return map;
    }

    public static void main(String[] args) {
        for (Map.Entry<String,String> entry: new SysDepsProps().call().entrySet()) {
            System.out.println(entry.getKey() + ": " + entry.getValue());
        }
    }
}
