/*
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "macqueenipc.h"

#include "config-kwin.h"
#include "core/output.h"
#include "virtualdesktops.h"
#include "window.h"
#include "workspace.h"

#include <QDBusConnection>

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
    QDBusConnection::sessionBus().unregisterService(m_serviceName);
}

uint MacqueenIpc::protocolVersion() const
{
    return 1;
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
