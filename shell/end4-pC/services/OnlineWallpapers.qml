pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string provider:   "wallhaven"  // "wallhaven" | "unsplash"
    property string resolution: "1080p"      // "1080p" | "2K" | "4K"
    property string query:      ""           // empty keyword = random
    property string category:   "general"    // wallhaven: "general"|"anime"|"people" / unsplash: "nature"|"city"|...
    property string purity:     "sfw"        // wallhaven: "sfw"|"sketchy"|"nsfw"
    property bool   loading:    false
    property bool   appending:  false 
    property int    page:       1
    property string seed:       ""          
    property var    results:    []           // list [ {thumb, full, id, provider} ]
    property int totalPages: 0

    signal fetched()
    signal fetchError(string message)

    // ─── APIs ───
    readonly property string unsplashClientId: KeyringStorage.keyringData?.apiKeys?.unsplash  ?? ""
    readonly property string wallhavenApiKey:  KeyringStorage.keyringData?.apiKeys?.wallhaven ?? ""
    // ─── Resolution ───
    readonly property var resolutionMap: ({
        "wallhaven": {
            "1080p": "1920x1080",
            "2K":    "2560x1440",
            "4K":    "3840x2160",
        },
        "unsplash": {
            "1080p": "&w=1920&h=1080&fit=crop",
            "2K":    "&w=2560&h=1440&fit=crop",
            "4K":    "&w=3840&h=2160&fit=crop",
        }
    })

    // ─── Purity wallhaven ───
    readonly property var purityMap: ({
        "sfw":     "100",
        "sketchy": "110",
        "nsfw":    "111",
    })

    function fetch() {
        if (root.loading) return;
        root.page = 1;
        root.seed = "";
        root.appending = false;
        root.results = [];
        _doFetch();
    }

    function nextPage() {
        if (root.loading) return;
        if (root.provider !== "unsplash" && root.totalPages > 0 && root.page >= root.totalPages) return;  // NUEVO: no pedir de más
        root.appending = true;   
        root.page += 1;
        _doFetch();
    }

    function prevPage() {
        if (root.loading || root.page <= 1) return;
        root.page -= 1;
        _doFetch();
    }

    function _doFetch() {
        root.loading = true;
        if (root.provider === "wallhaven") {
            _fetchWallhaven();
        } else if (root.provider === "unsplash") {
            _fetchUnsplash();
        } else {
            root.loading = false;
            root.fetchError("Unsupported wallpaper provider");
        }
    }

    function goToPage(n) {
        root.page = n;
        _doFetch();
    }

    function _fetchWallhaven() {
        const res      = root.resolutionMap["wallhaven"][root.resolution] ?? "1920x1080";
        const purity   = root.purityMap[root.purity] ?? "100";
        const q        = root.query.length > 0 ? `&q=${encodeURIComponent(root.query)}` : ""; 
        const seedParam = root.seed.length > 0 ? `&seed=${encodeURIComponent(root.seed)}` : "";

        const url = `https://wallhaven.cc/api/v1/search?sorting=random&purity=${purity}&categories=100&ratios=16x9&atleast=${res}&page=${root.page}${seedParam}${q}`;

        fetchProc.provider = "wallhaven";
        const command = [
            "curl", "--fail", "--silent", "--show-error", "--location",
            "--proto", "=https", "--proto-redir", "=https",
            "--connect-timeout", "8", "--max-time", "20",
            "--max-filesize", "2097152",
        ];
        if (root.wallhavenApiKey.length > 0) {
            command.push("--header", `X-API-Key: ${root.wallhavenApiKey}`);
        }
        command.push(url);
        fetchProc.command = command;
        fetchProc.running = true;
    }

    function _fetchUnsplash() {
        const orientation = "landscape";
        const count       = 24;
        const q           = root.query.length > 0 ? `&query=${encodeURIComponent(root.query)}` : `&query=${encodeURIComponent(root.category)}`;  
        const clientId    = root.unsplashClientId;
        if (clientId.length === 0) {
            root.loading = false;
            root.fetchError("Unsplash API key not set");
            return;
        }

        const url = `https://api.unsplash.com/photos/random?orientation=${orientation}&count=${count}${q}`;

        fetchProc.provider = "unsplash";
        fetchProc.command = [
            "curl", "--fail", "--silent", "--show-error", "--location",
            "--proto", "=https", "--proto-redir", "=https",
            "--connect-timeout", "8", "--max-time", "20",
            "--max-filesize", "2097152",
            "--header", `Authorization: Client-ID ${clientId}`,
            url,
        ];
        fetchProc.running = true;
    }

    function _withUnsplashAttribution(url) {
        const value = String(url ?? "");
        if (value.length === 0) return "";
        const separator = value.includes("?") ? "&" : "?";
        return `${value}${separator}utm_source=desktop-ui&utm_medium=referral`;
    }

    function _unsplashImageUrl(rawUrl) {
        const value = String(rawUrl ?? "");
        if (value.length === 0) return "";
        const size = root.resolutionMap["unsplash"][root.resolution]
            ?? "&w=1920&h=1080&fit=crop";
        const separator = value.includes("?") ? "&" : "?";
        return value + separator + size.replace(/^&/, "") + "&fm=jpg&q=85";
    }

    function _parseWallhaven(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);
            if (data.meta?.seed && root.seed.length === 0) {
                root.seed = data.meta.seed;
            }
            root.totalPages = data.meta?.last_page ?? 0
            const newItems = data.data.map(item => ({
                url:              item.url ?? item.short_url ?? "",
                id:               item.id,
                thumb:            item.thumbs.large,
                full:             item.path,
                provider:         "wallhaven",
                title:            "",
                author:           item.uploader?.username ?? "",
                authorUrl:        item.uploader?.username
                    ? `https://wallhaven.cc/user/${encodeURIComponent(item.uploader.username)}`
                    : "",
                attributionUrl:   item.url ?? item.short_url ?? "",
                itemUrl:          item.url ?? item.short_url ?? "",
                uploader:         item.uploader ?? null,
                likes:            0,
                width:            item.dimension_x ?? 0,
                height:           item.dimension_y ?? 0,
                downloadLocation: "",
            }));
            root.results = root.appending ? root.results.concat(newItems) : newItems;   // CAMBIO
            root.fetched();
        } catch (e) {
            root.fetchError("Wallhaven parse error: " + e);
        }
    }

    function _parseUnsplash(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);

            const newItems = data.map(item => ({
                url:              root._withUnsplashAttribution(item.links?.html),
                id:               item.id,
                thumb:            item.urls.small,
                full:             root._unsplashImageUrl(item.urls?.raw),
                provider:         "unsplash",
                title:            item.alt_description ?? item.description ?? "",
                author:           item.user?.name ?? "",
                authorUrl:        root._withUnsplashAttribution(item.user?.links?.html),
                attributionUrl:   root._withUnsplashAttribution(item.links?.html),
                itemUrl:          root._withUnsplashAttribution(item.links?.html),
                uploader:         item.user ?? null,
                likes:            item.likes ?? 0,
                width:            item.width ?? 0,
                height:           item.height ?? 0,
                downloadLocation: item.links?.download_location ?? "",
            }));

            root.results = root.appending ? root.results.concat(newItems) : newItems;
            root.fetched();
        } catch (e) {
            root.fetchError("Unsplash parse error: " + e);
        }
    }

    // ─── Process ───
    Process {
        id: fetchProc
        property string provider: ""
        property string buffer:   ""

        onRunningChanged: {
            if (running) buffer = "";
        }

        stdout: SplitParser {
            onRead: data => {
                fetchProc.buffer += data;
            }
        }

        onExited: (exitCode) => {
            root.loading = false;
            if (exitCode !== 0) {
                root.fetchError("curl exited with code " + exitCode);
                return;
            }
            if (fetchProc.provider === "wallhaven") {
                root._parseWallhaven(fetchProc.buffer);
            } else if (fetchProc.provider === "unsplash") {
                root._parseUnsplash(fetchProc.buffer);
            }
        }
    }
}
