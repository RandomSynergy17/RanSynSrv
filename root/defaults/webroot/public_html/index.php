<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RanSynSrv</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            color: #eee;
        }
        .container { text-align: center; padding: 2rem; max-width: 1200px; width: 100%; }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
            background: linear-gradient(90deg, #e94560, #ff6b6b);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle { font-size: 1rem; opacity: 0.8; margin-bottom: 2rem; }
        .links { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; margin-bottom: 1rem; }
        a, button {
            padding: 0.6rem 1.2rem;
            background: rgba(233, 69, 96, 0.15);
            border: 1px solid #e94560;
            border-radius: 6px;
            color: #e94560;
            text-decoration: none;
            transition: all 0.2s;
            cursor: pointer;
            font-family: inherit;
            font-size: 1rem;
        }
        a:hover, button:hover { background: #e94560; color: #fff; }
        .status { margin-top: 1rem; font-family: monospace; font-size: 0.85rem; opacity: 0.7; }

        /* PHPInfo section */
        .phpinfo-section {
            margin-top: 2rem;
            display: none;
            max-height: 70vh;
            overflow-y: auto;
            background: rgba(15, 52, 96, 0.5);
            border: 1px solid rgba(233, 69, 96, 0.3);
            border-radius: 8px;
            padding: 1.5rem;
        }
        .phpinfo-section.show { display: block; }

        /* Style phpinfo() output */
        .phpinfo-section table {
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
            font-size: 0.85rem;
        }
        .phpinfo-section th, .phpinfo-section td {
            padding: 0.5rem;
            text-align: left;
            border-bottom: 1px solid rgba(233, 69, 96, 0.2);
        }
        .phpinfo-section th {
            background: rgba(233, 69, 96, 0.2);
            color: #ff6b6b;
            font-weight: 600;
        }
        .phpinfo-section td {
            background: rgba(15, 52, 96, 0.3);
            color: #eee;
        }
        .phpinfo-section h2 {
            color: #e94560;
            margin: 1.5rem 0 1rem 0;
            font-size: 1.5rem;
        }
        .phpinfo-section h1 {
            color: #ff6b6b;
            margin-bottom: 1rem;
            background: none;
            -webkit-text-fill-color: #ff6b6b;
        }
        .phpinfo-section a {
            color: #e94560;
            background: none;
            border: none;
            padding: 0;
        }

        /* Scrollbar styling */
        .phpinfo-section::-webkit-scrollbar { width: 10px; }
        .phpinfo-section::-webkit-scrollbar-track { background: rgba(15, 52, 96, 0.3); }
        .phpinfo-section::-webkit-scrollbar-thumb {
            background: rgba(233, 69, 96, 0.5);
            border-radius: 5px;
        }
        .phpinfo-section::-webkit-scrollbar-thumb:hover { background: rgba(233, 69, 96, 0.7); }
    </style>
</head>
<body>
    <div class="container">
        <h1>RanSynSrv</h1>
        <p class="subtitle">Nginx + PHP 8.4 + GoAccess + Claude Code</p>
        <div class="links">
            <a href="/goaccess">Analytics</a>
            <a href="/health">Health</a>
            <button onclick="togglePhpInfo()">PHP Info</button>
        </div>
        <p class="status">Server is running</p>

        <div id="phpinfo" class="phpinfo-section">
            <?php
            ob_start();
            phpinfo();
            $phpinfo = ob_get_clean();

            // Remove the HTML, HEAD, and BODY tags from phpinfo output
            $phpinfo = preg_replace('%^.*<body>(.*)</body>.*$%ms', '$1', $phpinfo);

            // Remove inline styles and use our custom styles
            $phpinfo = preg_replace('/<style[^>]*>.*?<\/style>/si', '', $phpinfo);

            echo $phpinfo;
            ?>
        </div>
    </div>

    <script>
        function togglePhpInfo() {
            const phpinfoSection = document.getElementById('phpinfo');
            phpinfoSection.classList.toggle('show');
        }
    </script>
</body>
</html>
