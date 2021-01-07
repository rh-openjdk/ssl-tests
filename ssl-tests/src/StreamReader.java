/*
 * The MIT License
 *
 * Copyright 2021 Zdeněk Žamberský.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import java.io.PrintStream;
import java.util.List;
import java.util.ArrayList;
import java.util.logging.Level;
import java.util.logging.Logger;

public class StreamReader {

    InputStream is;
    List<String> lines;
    Thread t;

    public StreamReader(InputStream is) {
        this.is = is;
        lines = new ArrayList();
        t = new Thread(new Runnable() {
            public void run() {
                try {
                    readAll();
                } catch (Exception ex) {
                    Logger.getLogger(StreamReader.class.getName())
                                    .log(Level.SEVERE, null, ex);
                }
            }
        });
    }

    private void readAll() throws IOException {
        try (InputStream is = this.is;
            InputStreamReader isr = new InputStreamReader(is);
            BufferedReader br = new BufferedReader(isr)) {
            String line = null;
            while ((line = br.readLine()) != null) {
                lines.add(line);
            }
        }
    }

    public void start() {
        t.start();
    }

    public void waitfor() throws InterruptedException {
        t.join();
    }

    public void printWithPrefix(PrintStream ps, String prefix) {
        for (String line: lines) {
            ps.println(prefix + line);
        }
    }
}
