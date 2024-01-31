import java.io.InputStream;
import java.io.IOException;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.FileSystems;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;
import java.util.concurrent.Callable;

public class SysDepsProps implements Callable<Map<String, String>> {

    Thread streamDiscarder(final InputStream is) {
        return new Thread() {
            @Override
            public void run() {
                try {
                    while (is.read() >= 0) { /* discard */ };
                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    try {
                        is.close();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            }
        };
    }

    Thread streamReader(final InputStream is, final List<String> linesBuf) {
        if (linesBuf == null) {
            return streamDiscarder(is);
        }
        return new Thread() {
            @Override
            public void run() {
                try (InputStreamReader isr = new InputStreamReader(is);
                    BufferedReader br = new BufferedReader(isr)){
                    String line;
                    while ((line = br.readLine()) != null) {
                        linesBuf.add(line);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    try {
                        is.close();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            }
        };
    }

    boolean runCmd(String[] command, List<String> stdoutBuf, List<String> stderrBuf) {
        ProcessBuilder pb = new  ProcessBuilder(command);
        Process p = null;
        Thread outReader = null;
        Thread errReader= null;
        int retVal = 0;
        try {
            p = pb.start(); // throws exception if program does not exist
            outReader = streamReader(p.getInputStream(), stdoutBuf);
            outReader.start();
            errReader = streamReader(p.getErrorStream(), stderrBuf);
            errReader.start();
            p.getOutputStream().close();
            p.waitFor();
            return true;
        } catch (Exception ex) {
            if (p != null) {
                p.destroy();
            }
        } finally {
            try {
                if (outReader != null) {
                    outReader.join();
                }
                if (errReader != null) {
                    errReader.join();
                }
            } catch (InterruptedException ex) {}
        }
        return false;
    }

    boolean checkOnPath(String cmd) {
        return runCmd(new String[]{cmd, "--help"}, null, null);
    }

    boolean containsString(List<String> list, String str) {
        for (String s : list) {
            if (s.contains(str)) {
                return true;
            }
        }
        return false;
    }

    boolean checkSupportsOption(String cmd, String option) {
        List<String> stdoutBuf = new ArrayList<String>();
        List<String> stderrBuf = new ArrayList<String>();
        if (!runCmd(new String[]{cmd, "--help"}, stdoutBuf, stderrBuf)) {
            return false;
        }
        return containsString(stdoutBuf, option) || containsString(stderrBuf, option);
    }

    boolean fileExists(String path) {
        return Files.exists(FileSystems.getDefault().getPath(path));
    }

    String getTstclntCmd() {
        String cmd = "/usr/lib64/nss/unsupported-tools/tstclnt";
        if (fileExists(cmd)) {
            return cmd;
        }
        cmd = "/usr/lib/nss/unsupported-tools/tstclnt";
        if (fileExists(cmd)) {
            return cmd;
        }
        cmd = "tstclnt";
        if (checkOnPath(cmd)) {
            return cmd;
        }
        return null;
    }

    boolean checkTstclnt() {
        String cmd = getTstclntCmd();
        return cmd == null ? false : checkSupportsOption(cmd, "-Q");
    }

    boolean checkGnutlsCli() {
        return checkOnPath("gnutls-cli");
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
