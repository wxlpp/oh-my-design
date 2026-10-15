/// Tree 拖动的起点；整行模式适用于没有长按菜单的目录。
public enum TreeDragSource: Sendable {
    /// 保留行尾拖动手柄，行内容可以拥有独立长按菜单。
    case handle
    /// 从整行长按起拖，不显示手柄；调用方不要再为该行绑定长按菜单。
    case row
}
