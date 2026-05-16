#include <QGuiApplication>
#include <QQuickView>
#include <QQmlEngine>
#include <QUrl>
#include <QDir>
#include <QDebug>
#include <QStandardPaths>

#include "audiorecorder.h"
#include "whisperclient.h"
#include "ttsclient.h"

int main(int argc, char *argv[]) {
    // PulseAudio refuses to initialize without XDG_RUNTIME_DIR.
    // In some sandboxed/Docker setups the env var is missing → falling back
    // to a writable temp dir keeps MediaPlayer/QAudioRecorder from blocking.
    if (qEnvironmentVariableIsEmpty("XDG_RUNTIME_DIR")) {
        QString fallback = QDir::tempPath() + "/runtime-" + qgetenv("USER");
        QDir().mkpath(fallback);
        qputenv("XDG_RUNTIME_DIR", fallback.toUtf8());
        qDebug() << "[main] XDG_RUNTIME_DIR was empty, set to" << fallback;
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ragassistant.ragassistant"));
    app.setOrganizationName(QStringLiteral("ragassistant.ragassistant"));

    qmlRegisterType<AudioRecorder>("Ragassistant.Audio", 1, 0, "AudioRecorder");
    qmlRegisterType<WhisperClient>("Ragassistant.Audio", 1, 0, "WhisperClient");
    qmlRegisterType<TtsClient>("Ragassistant.Audio", 1, 0, "TtsClient");

    QQuickView view;
    view.setResizeMode(QQuickView::SizeRootObjectToView);

    const QString qmlPath = QDir(app.applicationDirPath()).filePath(QStringLiteral("qml/Main.qml"));
    qDebug() << "[main] loading QML from:" << qmlPath;

    view.setSource(QUrl::fromLocalFile(qmlPath));

    if (view.status() == QQuickView::Error) {
        qWarning() << "[main] QML load errors:";
        for (const auto &e : view.errors()) qWarning() << "  " << e.toString();
        return 1;
    }

    view.show();
    return app.exec();
}
