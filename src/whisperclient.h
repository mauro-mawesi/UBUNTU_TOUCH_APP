#ifndef WHISPERCLIENT_H
#define WHISPERCLIENT_H

#include <QObject>
#include <QNetworkAccessManager>

class WhisperClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit WhisperClient(QObject *parent = nullptr);
    bool busy() const { return m_busy; }

public slots:
    void transcribe(const QString &serverUrl, const QString &filePath,
                    const QString &language, const QString &model);

signals:
    void transcribed(const QString &text);
    void errorOccurred(const QString &message);
    void busyChanged();

private:
    void setBusy(bool b);
    QNetworkAccessManager m_nam;
    bool m_busy = false;
};

#endif // WHISPERCLIENT_H
