const path = require('path');

module.exports = {
    userDir: '/opt/Freya/nodered',
    flowFile: 'flows/Freya_flows.json',
    library: {
        user: path.join(__dirname, 'flows', 'lib')
    },
    flowFilePretty: true,

    diagnostics: {
        enabled: true,
        ui: true,
    },

    runtimeState: {
        enabled: false,
        ui: false,
    },

    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    },

    functionExternalModules: true,
    functionTimeout: 0,

    exportGlobalContextKeys: false,

    externalModules: {},

    editorTheme: {
        theme: "freya",
        page: {
            title: "Freya",
            favicon: "/favicon.ico"
        },
        header: {
            title: " ",
            url: "/",
        },
        palette: {},
        projects: {
            enabled: true,
            workflow: {
                mode: "manual"
            }
        },
        codeEditor: {
            lib: "monaco",
            options: {}
        },
        markdownEditor: {
            mermaid: {
                enabled: true
            }
        },
        multiplayer: {
            enabled: false
        }
    },

    // Serve static files from /opt/Freya/assets
    httpStatic: '/opt/Freya/assets',

    // Network settings
    uiPort: process.env.PORT || 80,
    // uiHost: "127.0.0.1", // commented to listen on all interfaces

    mqttReconnectTime: 15000,
    serialReconnectTime: 15000,

    debugMaxLength: 1000,

};
