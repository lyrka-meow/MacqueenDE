/*
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "macqueenipc.h"

#include "config-kwin.h"
#include "core/output.h"
#include "input.h"
#include "keyboard_input.h"
#include "keyboard_layout.h"
#include "main.h"
#include "screenedge.h"
#include "virtualdesktops.h"
#include "window.h"
#include "workspace.h"
#include "xkb.h"

#include <QDBusConnection>
#include <QFile>
#include <QAction>
#include <QKeySequence>
#include <KGlobalAccel>
#include <KConfigGroup>
#include <QRegularExpression>
#include <QTextStream>

namespace KWin
{

namespace
{

QString windowId(const Window *window)
{
    return window ? window->internalId().toString(QUuid::WithoutBraces) : QString();
}

QVariantMap geometryData(const RectF &geometry)
{
    return {
        {QStringLiteral("x"), geometry.x()},
        {QStringLiteral("y"), geometry.y()},
        {QStringLiteral("width"), geometry.width()},
        {QStringLiteral("height"), geometry.height()},
    };
}

}

MacqueenIpc::MacqueenIpc(Workspace *workspace)
    : QObject(workspace)
    , m_workspace(workspace)
{
    m_screenshotAction = new QAction(this);
    m_screenshotAction->setObjectName(QStringLiteral("MacqueenInteractiveScreenshot"));
    m_screenshotAction->setText(QStringLiteral("Interactive Screenshot"));
    KGlobalAccel::self()->setGlobalShortcut(
        m_screenshotAction,
        QKeySequence(Qt::META | Qt::SHIFT | Qt::Key_S));
    connect(m_screenshotAction, &QAction::triggered, this, &MacqueenIpc::requestScreenshot);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerObject(QStringLiteral("/org/macqueen/Compositor1"),
                       this,
                       QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals);
    bus.registerService(m_serviceName);

    for (Window *window : m_workspace->windows()) {
        watchWindow(window);
    }

    connect(m_workspace, &Workspace::windowAdded, this, [this](Window *window) {
        watchWindow(window);
        if (window->isClient()) {
            Q_EMIT windowAdded(windowId(window));
        }
    });
    connect(m_workspace, &Workspace::windowRemoved, this, [this](Window *window) {
        if (window->isClient()) {
            Q_EMIT windowRemoved(windowId(window));
        }
    });
    connect(m_workspace, &Workspace::windowActivated, this, [this](Window *window) {
        Q_EMIT activeWindowChanged(windowId(window));
    });
    connect(m_workspace, &Workspace::outputsChanged, this, &MacqueenIpc::outputsChanged);
    m_workspace->screenEdges()->reserve(ElectricTopLeft, this, "overviewBorderActivated");
    if (input() && input()->keyboard() && input()->keyboard()->keyboardLayout()) {
        connect(input()->keyboard()->keyboardLayout(),
                &KeyboardLayout::layoutsReconfigured,
                this,
                &MacqueenIpc::keyboardLayoutsChanged);
        connect(input()->keyboard()->keyboardLayout(),
                &KeyboardLayout::layoutChanged,
                this,
                &MacqueenIpc::keyboardLayoutsChanged);
    }
    connect(m_workspace, &Workspace::currentDesktopChanged, this, [this]() {
        Q_EMIT workspacesChanged();
    });

    VirtualDesktopManager *desktops = VirtualDesktopManager::self();
    connect(desktops, &VirtualDesktopManager::countChanged, this, [this]() {
        Q_EMIT workspacesChanged();
    });
    connect(desktops, &VirtualDesktopManager::desktopMoved, this, [this]() {
        Q_EMIT workspacesChanged();
    });
    for (VirtualDesktop *desktop : desktops->desktops()) {
        connect(desktop, &VirtualDesktop::nameChanged, this, &MacqueenIpc::workspacesChanged);
    }
    connect(desktops, &VirtualDesktopManager::desktopAdded, this, [this](VirtualDesktop *desktop) {
        connect(desktop, &VirtualDesktop::nameChanged, this, &MacqueenIpc::workspacesChanged);
    });
}

MacqueenIpc::~MacqueenIpc()
{
    m_workspace->screenEdges()->unreserve(ElectricTopLeft, this);
    QDBusConnection::sessionBus().unregisterService(m_serviceName);
}

uint MacqueenIpc::protocolVersion() const
{
    return 4;
}

QString MacqueenIpc::compositorVersion() const
{
    return QString::fromLatin1(MACQUEEN_VERSION_STRING);
}

QVariantMap MacqueenIpc::activeWindow() const
{
    return windowData(m_workspace->activeWindow());
}

QVariantList MacqueenIpc::windows() const
{
    QVariantList result;
    for (const Window *window : m_workspace->windows()) {
        if (window->isClient()) {
            result.append(windowData(window));
        }
    }
    return result;
}

QVariantList MacqueenIpc::outputs() const
{
    QVariantList result;
    for (const LogicalOutput *output : m_workspace->outputs()) {
        const Rect geometry = output->geometry();
        result.append(QVariantMap{
            {QStringLiteral("id"), output->uuid()},
            {QStringLiteral("name"), output->name()},
            {QStringLiteral("manufacturer"), output->manufacturer()},
            {QStringLiteral("model"), output->model()},
            {QStringLiteral("serialNumber"), output->serialNumber()},
            {QStringLiteral("x"), geometry.x()},
            {QStringLiteral("y"), geometry.y()},
            {QStringLiteral("width"), geometry.width()},
            {QStringLiteral("height"), geometry.height()},
            {QStringLiteral("scale"), output->scale()},
            {QStringLiteral("refreshRate"), output->refreshRate()},
        });
    }
    return result;
}

QVariantList MacqueenIpc::workspaces() const
{
    QVariantList result;
    VirtualDesktopManager *manager = VirtualDesktopManager::self();
    const VirtualDesktop *current = manager->currentDesktop();
    for (const VirtualDesktop *desktop : manager->desktops()) {
        result.append(QVariantMap{
            {QStringLiteral("id"), desktop->id()},
            {QStringLiteral("name"), desktop->name()},
            {QStringLiteral("position"), desktop->x11DesktopNumber()},
            {QStringLiteral("current"), desktop == current},
        });
    }
    return result;
}

QVariantList MacqueenIpc::keyboardLayouts() const
{
    QVariantList result;
    if (!input() || !input()->keyboard()) {
        return result;
    }

    Xkb *xkb = input()->keyboard()->xkb();
    const uint current = xkb->currentLayout();
    for (uint index = 0; index < xkb->numberOfLayouts(); ++index) {
        QString code = xkb->layoutShortName(index);
        // xkbcommon uses "us" when no layout is explicitly configured, while
        // the corresponding rule name remains empty.
        if (code.isEmpty()) {
            code = QStringLiteral("us");
        }
        result.append(QVariantMap{
            {QStringLiteral("code"), code},
            {QStringLiteral("name"), xkb->layoutName(index)},
            {QStringLiteral("index"), index},
            {QStringLiteral("active"), index == current},
        });
    }
    return result;
}

QVariantList MacqueenIpc::availableKeyboardLayouts() const
{
    QFile file(QStringLiteral("/usr/share/X11/xkb/rules/evdev.lst"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        file.setFileName(QStringLiteral("/usr/share/X11/xkb/rules/base.lst"));
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return {};
        }
    }

    QVariantList result;
    QTextStream stream(&file);
    bool inLayouts = false;
    const QRegularExpression entry(QStringLiteral("^\\s*(\\S+)\\s+(.+?)\\s*$"));
    while (!stream.atEnd()) {
        const QString line = stream.readLine();
        if (line.startsWith(QLatin1Char('!'))) {
            inLayouts = line.trimmed() == QStringLiteral("! layout");
            continue;
        }
        if (!inLayouts || line.trimmed().isEmpty()) {
            continue;
        }
        const QRegularExpressionMatch match = entry.match(line);
        if (match.hasMatch()) {
            result.append(QVariantMap{
                {QStringLiteral("code"), match.captured(1)},
                {QStringLiteral("name"), match.captured(2)},
            });
        }
    }
    return result;
}

uint MacqueenIpc::currentKeyboardLayout() const
{
    return input() && input()->keyboard() ? input()->keyboard()->xkb()->currentLayout() : 0;
}

bool MacqueenIpc::setKeyboardLayouts(const QStringList &layouts)
{
    static const QRegularExpression validLayout(QStringLiteral("^[A-Za-z0-9_()+-]+$"));
    if (layouts.isEmpty()) {
        return false;
    }
    for (const QString &layout : layouts) {
        if (!validLayout.match(layout).hasMatch()) {
            return false;
        }
    }

    KConfigGroup group(kwinApp()->kxkbConfig(), QStringLiteral("Layout"));
    group.writeEntry(QStringLiteral("Use"), true, KConfig::Notify);
    group.writeEntry(QStringLiteral("LayoutList"), layouts.join(QLatin1Char(',')), KConfig::Notify);
    group.writeEntry(QStringLiteral("VariantList"), QStringList(layouts.size(), QString()).join(QLatin1Char(',')), KConfig::Notify);
    group.sync();

    // Apply the new keymap immediately. KConfig notifications are not guaranteed
    // to be delivered back to the process that wrote the configuration.
    input()->keyboard()->xkb()->reconfigure();
    input()->keyboard()->keyboardLayout()->resetLayout();
    return true;
}

bool MacqueenIpc::setCurrentKeyboardLayout(uint index)
{
    if (!input() || !input()->keyboard() || index >= input()->keyboard()->xkb()->numberOfLayouts()) {
        return false;
    }
    input()->keyboard()->keyboardLayout()->switchToLayout(index);
    return true;
}

bool MacqueenIpc::activateWorkspace(const QString &id)
{
    VirtualDesktopManager *manager = VirtualDesktopManager::self();
    VirtualDesktop *desktop = manager->desktopForId(id);
    return desktop && (desktop == manager->currentDesktop() || manager->setCurrent(desktop));
}

QString MacqueenIpc::createWorkspace(uint position, const QString &name)
{
    VirtualDesktopManager *manager = VirtualDesktopManager::self();
    const uint insertionIndex = position == 0 ? manager->count() : position - 1;
    VirtualDesktop *desktop = manager->createVirtualDesktop(insertionIndex, name);
    return desktop ? desktop->id() : QString();
}

bool MacqueenIpc::removeWorkspace(const QString &id)
{
    VirtualDesktopManager *manager = VirtualDesktopManager::self();
    VirtualDesktop *desktop = manager->desktopForId(id);
    if (!desktop || manager->count() <= 1) {
        return false;
    }
    manager->removeVirtualDesktop(desktop);
    return true;
}

bool MacqueenIpc::renameWorkspace(const QString &id, const QString &name)
{
    VirtualDesktop *desktop = VirtualDesktopManager::self()->desktopForId(id);
    if (!desktop || name.trimmed().isEmpty()) {
        return false;
    }
    desktop->setName(name.trimmed());
    return true;
}

bool MacqueenIpc::activateWindow(const QString &id)
{
    Window *window = m_workspace->findWindow(QUuid::fromString(id));
    if (!window || !window->isClient()) {
        return false;
    }
    m_workspace->activateWindow(window, true);
    return true;
}

bool MacqueenIpc::closeWindow(const QString &id)
{
    Window *window = m_workspace->findWindow(QUuid::fromString(id));
    if (!window || !window->isClient() || !window->isCloseable()) {
        return false;
    }
    window->closeWindow();
    return true;
}

bool MacqueenIpc::setWindowMinimized(const QString &id, bool minimized)
{
    Window *window = m_workspace->findWindow(QUuid::fromString(id));
    if (!window || !window->isClient() || (minimized && !window->isMinimizable())) {
        return false;
    }
    window->setMinimized(minimized);
    return true;
}

bool MacqueenIpc::setWindowFullscreen(const QString &id, bool fullscreen)
{
    Window *window = m_workspace->findWindow(QUuid::fromString(id));
    if (!window || !window->isClient() || (fullscreen && !window->isFullScreenable())) {
        return false;
    }
    window->setFullScreen(fullscreen);
    return true;
}

bool MacqueenIpc::moveWindowToWorkspace(const QString &windowId, const QString &workspaceId)
{
    Window *window = m_workspace->findWindow(QUuid::fromString(windowId));
    VirtualDesktop *desktop = VirtualDesktopManager::self()->desktopForId(workspaceId);
    if (!window || !window->isClient() || !desktop) {
        return false;
    }
    window->setDesktops({desktop});
    return true;
}

void MacqueenIpc::requestOverview(const QString &reason)
{
    Q_EMIT overviewRequested(reason);
}

QString MacqueenIpc::screenshotShortcut() const
{
    const auto shortcuts = KGlobalAccel::self()->shortcut(m_screenshotAction);
    if (shortcuts.isEmpty()) {
        return {};
    }
    QString text = shortcuts.constFirst().toString(QKeySequence::PortableText);
    return text.replace(QStringLiteral("Meta"), QStringLiteral("Super"));
}

bool MacqueenIpc::setScreenshotShortcut(const QString &shortcut)
{
    QString portable = shortcut.trimmed();
    portable.replace(QStringLiteral("Super"), QStringLiteral("Meta"), Qt::CaseInsensitive);
    const QKeySequence sequence = QKeySequence::fromString(portable, QKeySequence::PortableText);
    if (!portable.isEmpty() && sequence.isEmpty()) {
        return false;
    }
    KGlobalAccel::self()->setShortcut(m_screenshotAction,
                                     sequence.isEmpty() ? QList<QKeySequence>{} : QList<QKeySequence>{sequence},
                                     KGlobalAccel::NoAutoloading);
    Q_EMIT screenshotShortcutChanged(screenshotShortcut());
    return true;
}

void MacqueenIpc::requestScreenshot()
{
    Q_EMIT screenshotRequested();
}

bool MacqueenIpc::overviewBorderActivated(ElectricBorder border)
{
    if (border != ElectricTopLeft) {
        return false;
    }
    requestOverview(QStringLiteral("screen-edge"));
    return true;
}

void MacqueenIpc::watchWindow(Window *window)
{
    if (!window->isClient()) {
        return;
    }

    const auto changed = [this, window](const QStringList &fields) {
        Q_EMIT windowChanged(windowId(window), fields);
    };
    connect(window, &Window::captionChanged, this, [changed]() {
        changed({QStringLiteral("title")});
    });
    connect(window, &Window::frameGeometryChanged, this, [changed]() {
        changed({QStringLiteral("geometry")});
    });
    connect(window, &Window::minimizedChanged, this, [changed]() {
        changed({QStringLiteral("minimized")});
    });
    connect(window, &Window::fullScreenChanged, this, [changed]() {
        changed({QStringLiteral("fullscreen")});
    });
    connect(window, &Window::maximizedChanged, this, [changed]() {
        changed({QStringLiteral("maximized")});
    });
    connect(window, &Window::desktopsChanged, this, [changed]() {
        changed({QStringLiteral("workspaces")});
    });
    connect(window, &Window::outputChanged, this, [changed]() {
        changed({QStringLiteral("output")});
    });
    connect(window, &Window::windowClassChanged, this, [changed]() {
        changed({QStringLiteral("appId")});
    });
}

QVariantMap MacqueenIpc::windowData(const Window *window) const
{
    if (!window || !window->isClient()) {
        return {};
    }

    return {
        {QStringLiteral("id"), windowId(window)},
        {QStringLiteral("appId"), window->desktopFileName().isEmpty() ? window->resourceClass() : window->desktopFileName()},
        {QStringLiteral("title"), window->captionNormal()},
        {QStringLiteral("geometry"), geometryData(window->frameGeometry())},
        {QStringLiteral("workspaces"), window->desktopIds()},
        {QStringLiteral("active"), window->isActive()},
        {QStringLiteral("minimized"), window->isMinimized()},
        {QStringLiteral("fullscreen"), window->isFullScreen()},
        {QStringLiteral("maximized"), window->maximizeMode() == MaximizeFull},
        {QStringLiteral("keepAbove"), window->keepAbove()},
        {QStringLiteral("skipTaskbar"), window->skipTaskbar()},
        {QStringLiteral("closeable"), window->isCloseable()},
        {QStringLiteral("minimizable"), window->isMinimizable()},
        {QStringLiteral("fullscreenable"), window->isFullScreenable()},
        {QStringLiteral("output"), window->output() ? window->output()->name() : QString()},
        {QStringLiteral("pid"), window->pid()},
    };
}

} // namespace KWin
