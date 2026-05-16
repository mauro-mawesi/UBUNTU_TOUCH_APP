#ifndef TTSCLIENT_H
#define TTSCLIENT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>

class QNetworkReply;

class TtsClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit TtsClient(QObject *parent = nullptr);
    bool busy() const { return m_busy; }

public slots:
    void synthesize(const QString &serverUrl, const QString &text,
                    const QString &voice, const QString &format);
    void cancel();

signals:
    void audioReady(const QString &filePath);
    void errorOccurred(const QString &message);
    void busyChanged();

private:
    void setBusy(bool b);
    QNetworkAccessManager m_nam;
    QPointer<QNetworkReply> m_currentReply;
    bool m_busy = false;
};

#endif // TTSCLIENT_H
