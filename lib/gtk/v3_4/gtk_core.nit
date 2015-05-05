# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2011-2013 Alexis Laferrière <alexis.laf@xymus.net>
# Copyright 2013 Nathan Heu <heu.nathan@courrier.uqam.ca>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Classes and services to use libGTK widgets
module gtk_core is
	pkgconfig "gtk+-3.0"
	cflags "-Wno-deprecated-declarations"
end

import gtk_enums
import gdk_enums

in "C Header" `{
	#include <gtk/gtk.h>
`}

`{
	/* callback user data */
	typedef struct {
		GtkCallable to_call;
		nullable_Object user_data;
	} NitGtkSignal;

	void nit_gtk_callback_func(GtkWidget *widget, gpointer callback_data) {
		NitGtkSignal *data;
		data = (NitGtkSignal*)callback_data;
		GtkCallable_signal(data->to_call, widget, data->user_data);
	}
`}

# Initialize the GTK system
fun init_gtk `{ gtk_init(0, NULL); `}

# Hand over control to the GTK event loop
fun run_gtk `{ gtk_main(); `}

# Quit the GTK event loop and clean up the system
fun quit_gtk `{ gtk_main_quit(); `}

interface GtkCallable
	# return true to stop event processing, false to let it propagate
	fun signal(sender: GtkWidget, user_data: nullable Object) is abstract
end

extern class GdkEvent `{GdkEvent *`}
end

# Base class for all widgets
# See: https://developer.gnome.org/gtk3/stable/GtkWidget.html
extern class GtkWidget `{GtkWidget *`}
	fun show_all `{ gtk_widget_show_all(recv); `}

	fun signal_connect(signal_name: String, to_call: GtkCallable, user_data: nullable Object) import String.to_cstring, GtkCallable.signal, Object.as not nullable `{
		NitGtkSignal *data = malloc(sizeof(NitGtkSignal));

		GtkCallable_incr_ref(to_call);
		Object_incr_ref(user_data);

		data->to_call = to_call;
		data->user_data = user_data;

		/*Use G_CALLBACK() to cast the callback function to a GCallback*/
		g_signal_connect(recv,
		                 String_to_cstring(signal_name),
		                 G_CALLBACK(nit_gtk_callback_func),
		                 data);
	`}

	redef fun ==(o) do return o isa GtkWidget and equal_to_gtk_widget(o)

	private fun equal_to_gtk_widget(o: GtkWidget): Bool `{
		return recv == o;
	`}

	fun request_size(width, height: Int) `{
		gtk_widget_set_size_request(recv, width, height);
	`}

	fun bg_color=(state: GtkStateType, color: GdkRGBA) `{
		gtk_widget_override_background_color(recv, state, color);
	`}

	# with gtk it's possible to set fg_color to all widget: is it correct? is fg color inherited?
	# GdkColor color;
	fun fg_color=(state: GtkStateType, color: GdkRGBA) `{
		gtk_widget_override_color(recv, state, color);
	`}

	# Sets the sensitivity of a widget. sensitive -> the user can interact with it.
	# Insensitive -> widget "grayed out" and the user can"t interact with them
	fun sensitive=(sensitive: Bool) `{
		gtk_widget_set_sensitive(recv, sensitive);
	`}

	# return the sensitivity of the widget
	fun sensitive: Bool `{
		return gtk_widget_get_sensitive(recv);
	`}

	# Set the visibility of the widget
	fun visible=(visible: Bool) `{
		gtk_widget_set_visible(recv, visible);
	`}

	# Get the visibility of the widget only
	fun visible_self: Bool `{
		return gtk_widget_get_visible(recv);
	`}

	# Destroy the widget
	fun destroy `{ gtk_widget_destroy(recv); `}

	# Show the widget on screen
	#
	# See: `show_all` to recursively show this widget and contained widgets.
	fun show `{ gtk_widget_show(recv); `}

	# Hide the widget (reverse the effects of `show`)
	fun hide `{ gtk_widget_hide(recv); `}
end

# Base class for widgets which contain other widgets
# See: https://developer.gnome.org/gtk3/stable/GtkContainer.html
extern class GtkContainer `{GtkContainer *`}
	super GtkWidget

	# Add a widget to the container
	fun add(widget: GtkWidget) `{
		gtk_container_add(recv, widget);
	`}
	# Remove the widget from the container
	fun remove_widget(widget: GtkWidget) `{
		gtk_container_remove(recv, widget);
	`}

	# Get the resize mode of the container
	fun resize_mode: GtkResizeMode `{
		return gtk_container_get_resize_mode(recv);
	`}

	# Set the resize mode of the container
	fun resize_mode=(resize_mode: GtkResizeMode) `{
		gtk_container_set_resize_mode(recv, resize_mode);
	`}

end

# A container with just one child
# See: https://developer.gnome.org/gtk3/stable/GtkBin.html
extern class GtkBin `{GtkBin *`}
	super GtkContainer

	fun child: GtkWidget `{
		return gtk_bin_get_child(recv);
	`}
end

# Toplevel which can contain other widgets
# See: https://developer.gnome.org/gtk3/stable/GtkWindow.html
extern class GtkWindow `{GtkWindow *`}
	super GtkBin

	new (flag: Int) `{
		GtkWindow *win;

		win = GTK_WINDOW(gtk_window_new(flag));
		g_signal_connect(win, "destroy", G_CALLBACK(gtk_main_quit), NULL);
		return win;
	`}

	fun title=(title: String) import String.to_cstring `{
		gtk_window_set_title(recv, String_to_cstring(title));
	`}

	# The "destroy" signal is emitted when a widget is destroyed, either by explicitly calling gtk_widget_destroy() or when the widget is unparented. Top-level GtkWindows are also destroyed when the Close window control button is clicked.
	fun on_close(to_call: GtkCallable, user_data: nullable Object)
	do
		signal_connect("destroy", to_call, user_data)
	end

	fun resizable: Bool `{
		return gtk_window_get_resizable(recv);
	`}

	fun resizable=(is_resizable: Bool) `{
		return gtk_window_set_resizable(recv, is_resizable);
	`}

	# Activates the current focused widget within the window.
	# returns TRUE if a widget got activated.
	fun activate_focus: Bool `{
		return gtk_window_activate_focus(recv);
	`}

	# Sets a window modal or non-modal. Modal windows prevent interaction with other windows in the same application.
	fun modal=(is_modal: Bool) `{
		gtk_window_set_modal(recv, is_modal);
	`}

	# Windows can't actually be 0x0 in size, they must be at least 1x1
	# but passing 0 for width and height is OK, resulting in a 1x1 default size.
	# params width in pixels, or -1 to unset the default width
	# params height in pixels, or -1 to unset the default height
	fun default_size(width: Int, height: Int) `{
		gtk_window_set_default_size(recv, width, height);
	`}

	# Activates the default widget for the window
	# unless the current focused widget has been configured to receive the default action (see gtk_widget_set_receives_default()), in which case the focused widget is activated.
	fun activate_default: Bool `{
		return gtk_window_activate_default(recv);
	`}

	fun gravity: GdkGravity `{
		return gtk_window_get_gravity(recv);
	`}

	fun gravity=(window_grav: GdkGravity) `{
		gtk_window_set_gravity(recv, window_grav);
	`}

#	fun position: GtkWindowPosition `{
#		return gtk_window_get_position(recv);
#	`}
#
#	fun position=(window_pos: GtkWindowPosition) `{
#		gtk_window_set_position(recv, window_pos);
#	`}

	fun active: Bool `{
		return gtk_window_is_active(recv);
	`}

	# Returns whether the input focus is within this GtkWindow. For real toplevel windows, this is identical to gtk_window_is_active(), but for embedded windows, like GtkPlug, the results will differ.
	fun has_toplevel_focus: Bool `{
		return gtk_window_has_toplevel_focus(recv);
	`}

	fun get_focus: GtkWidget `{
		return gtk_window_get_focus(recv);
	`}

	fun set_focus(widget: GtkWidget) `{
		return gtk_window_set_focus(recv, widget);
	`}

	fun get_default_widget: GtkWidget `{
		return gtk_window_get_default_widget(recv);
	`}

	fun set_default_widget(widget: GtkWidget) `{
		return gtk_window_set_default(recv, widget);
	`}

	fun maximize `{
		return gtk_window_maximize(recv);
	`}

	fun unmaximize `{
		return gtk_window_unmaximize(recv);
	`}

	fun fullscreen `{
		return gtk_window_fullscreen(recv);
	`}

	fun unfullscreen `{
		return gtk_window_unfullscreen(recv);
	`}

	fun keep_above=(setting: Bool) `{
		gtk_window_set_keep_above(recv, setting);
	`}

	fun keep_below=(setting: Bool) `{
		gtk_window_set_keep_below(recv, setting);
	`}
end

# A bin with a decorative frame and optional label
# https://developer.gnome.org/gtk3/stable/GtkFrame.html
extern class GtkFrame `{GtkFrame *`}
	super GtkBin

	new (lbl: String) import String.to_cstring `{
		return (GtkFrame *)gtk_frame_new(String_to_cstring(lbl));
	`}

	fun frame_label: String `{
		return NativeString_to_s((char *)gtk_frame_get_label(recv));
	`}

	fun frame_label=(lbl: String) import String.to_cstring `{
		gtk_frame_set_label(recv, String_to_cstring(lbl));
	`}

	fun label_widget: GtkWidget `{
		return gtk_frame_get_label_widget(recv);
	`}

	fun label_widget=(widget: GtkWidget) `{
		gtk_frame_set_label_widget(recv, widget);
	`}

	fun shadow_type: GtkShadowType `{
		return gtk_frame_get_shadow_type(recv);
	`}

	fun shadow_type=(stype: GtkShadowType) `{
		gtk_frame_set_shadow_type(recv, stype);
	`}

	fun label_align=(xalign: Float, yalign: Float) `{
		gtk_frame_set_label_align(recv, xalign, yalign);
	`}
end

# Pack widgets in a rows and columns
# See: https://developer.gnome.org/gtk3/3.3/GtkGrid.html
extern class GtkGrid `{GtkGrid *`}
	super GtkContainer

	# Create a new grid
	new `{
		return (GtkGrid*)gtk_grid_new();
	`}

	# Set a widget child inside the grid at a given position
	fun attach(child: GtkWidget, left, top, width, height: Int) `{
		gtk_grid_attach(recv, child, left, top, width, height);
	`}

	# Get the child of the Grid at the given position
	fun get_child_at(left: Int, top: Int): GtkWidget `{
		return gtk_grid_get_child_at(recv, left, top);
	`}

	# Insert a row at the specified position
	fun insert_row(position:Int) `{
		gtk_grid_insert_row(recv, position);
	`}

	# Insert a column at the specified position
	fun insert_column(position: Int) `{
		gtk_grid_insert_column(recv, position);
	`}
end

# A widget that can switch orientation
extern class GtkOrientable `{GtkOrientable *`}
	super GtkWidget

	# Get the orientation of this widget
	fun orientation: GtkOrientation `{
		return gtk_orientable_get_orientation(recv);
	`}

	# Set the orientation of this widget
	fun orientation=(orientation: GtkOrientation) `{
		gtk_orientable_set_orientation(recv, orientation);
	`}
end

# A container box
#
# See: https://developer.gnome.org/gtk3/3.4/GtkBox.html
extern class GtkBox `{ GtkBox * `}
	super GtkContainer
end

# The tree interface used by GtkTreeView
# See: https://developer.gnome.org/gtk3/stable/GtkTreeModel.html
extern class GtkTreeModel `{GtkTreeModel *`}
end

# An abstract class for laying out GtkCellRenderers
# See: https://developer.gnome.org/gtk3/stable/GtkCellArea.html
extern class GtkCellArea `{GtkCellArea *`}
end

# Base class for widgets with alignments and padding
# See: https://developer.gnome.org/gtk3/3.2/GtkMisc.html
extern class GtkMisc `{GtkMisc *`}
	super GtkWidget

	fun alignment: GtkAlignment is abstract

	fun alignment=(x: Float, y: Float) `{
		gtk_misc_set_alignment(recv, x, y);
	`}

	fun padding: GtkAlignment is abstract

	fun padding=(x: Float, y: Float) `{
		gtk_misc_set_padding(recv, x, y);
	`}

end

# A single line text entry field
# See: https://developer.gnome.org/gtk3/3.2/GtkEntry.html
extern class GtkEntry `{GtkEntry *`}
	super GtkWidget

	new `{
		 return (GtkEntry *)gtk_entry_new();
	`}

	fun text: String import NativeString.to_s_with_copy `{
		return NativeString_to_s_with_copy((char *)gtk_entry_get_text(recv));
	`}

	fun text=(value: String) import String.to_cstring `{
		gtk_entry_set_text(recv, String_to_cstring(value));
	`}

	# Is the text visible or is it the invisible char (such as '*')?
	fun visiblility: Bool `{
		return gtk_entry_get_visibility(recv);
	`}

	# Set the text visiblility
	# If false, will use the invisible char (such as '*')
	fun visibility=(is_visible: Bool) `{
		gtk_entry_set_visibility(recv, is_visible);
	`}

	fun max_length: Int `{
		return gtk_entry_get_max_length(recv);
	`}

	fun max_length=(max: Int) `{
		gtk_entry_set_max_length(recv, max);
	`}
end

# Base class for widgets which visualize an adjustment
# See: https://developer.gnome.org/gtk3/3.2/GtkRange.html
extern class GtkRange `{GtkRange *`}
	super GtkWidget

	# Gets the current position of the fill level indicator.
	fun fill_level: Float `{
		return gtk_range_get_fill_level(recv);
	`}

	fun fill_level=(level: Float) `{
		gtk_range_set_fill_level(recv, level);
	`}

	# Gets whether the range is restricted to the fill level.
	fun restricted_to_fill_level: Bool `{
		return gtk_range_get_restrict_to_fill_level(recv);
	`}

	fun restricted_to_fill_level=(restricted: Bool) `{
		gtk_range_set_restrict_to_fill_level(recv, restricted);
	`}

	# Gets whether the range displays the fill level graphically.
	fun show_fill_level: Bool `{
		return gtk_range_get_show_fill_level(recv);
	`}

	fun show_fill_level=(is_displayed: Bool) `{
		gtk_range_set_show_fill_level(recv, is_displayed);
	`}

	fun adjustment: GtkAdjustment `{
		return gtk_range_get_adjustment(recv);
	`}

	fun adjustment=(value: GtkAdjustment) `{
		gtk_range_set_adjustment(recv, value);
	`}

	fun inverted: Bool `{
		return gtk_range_get_inverted(recv);
	`}

	fun inverted=(setting: Bool) `{
		gtk_range_set_inverted(recv, setting);
	`}

	fun value: Float `{
		return gtk_range_get_value(recv);
	`}

	fun value=(val: Float) `{
		gtk_range_set_value(recv, val);
	`}

	fun set_increments(step: Float, page: Float) `{
		gtk_range_set_increments(recv, step, page);
	`}

	fun set_range(min: Float, max: Float) `{
		gtk_range_set_range(recv, min, max);
	`}

	fun round_digits: Int `{
		return gtk_range_get_round_digits(recv);
	`}

	fun round_digits=(nb: Int) `{
		gtk_range_set_round_digits(recv, nb);
	`}

	fun size_fixed: Bool `{
		return gtk_range_get_slider_size_fixed(recv);
	`}

	fun size_fixed=(is_fixed: Bool) `{
		return gtk_range_set_slider_size_fixed(recv, is_fixed);
	`}

	fun flippable: Bool `{
		return gtk_range_get_flippable(recv);
	`}

	fun min_size=(is_flippable: Bool) `{
		return gtk_range_set_flippable(recv, is_flippable);
	`}

	fun min_slider_size: Int `{
		return gtk_range_get_min_slider_size(recv);
	`}

	fun min_slider_size=(size: Int) `{
		return gtk_range_set_min_slider_size(recv, size);
	`}
end

# A slider widget for selecting a value from a range
# See: https://developer.gnome.org/gtk3/3.2/GtkScale.html
extern class GtkScale `{GtkScale *`}
	super GtkRange

	new (orientation: GtkOrientation, adjustment: GtkAdjustment) `{
		return (GtkScale *)gtk_scale_new(orientation, adjustment);
	`}

	new with_range (orientation: GtkOrientation, min: Float, max: Float, step: Float) `{
		return (GtkScale *)gtk_scale_new_with_range(orientation, min, max, step);
	`}

	fun digits: Int `{
		return gtk_scale_get_digits(recv);
	`}

	fun digits=(nb_digits: Int) `{
		gtk_scale_set_digits(recv, nb_digits);
	`}

	fun draw_value: Bool `{
		return gtk_scale_get_draw_value(recv);
	`}

	fun draw_value=(is_displayed: Bool) `{
		gtk_scale_set_draw_value(recv, is_displayed);
	`}

	fun value_position: GtkPositionType `{
		return gtk_scale_get_value_pos(recv);
	`}

	fun value_position=(pos: GtkPositionType) `{
		gtk_scale_set_value_pos(recv, pos);
	`}

	fun has_origin: Bool `{
		return gtk_scale_get_has_origin(recv);
	`}

	fun has_origin=(orig: Bool) `{
		gtk_scale_set_has_origin(recv, orig);
	`}

	fun add_mark(value: Float, position: GtkPositionType, markup: String)
	import String.to_cstring `{
		gtk_scale_add_mark(recv, value, position, String_to_cstring(markup));
	`}

	# Removes any marks that have been added with gtk_scale_add_mark().
	fun clear_marks `{
		gtk_scale_clear_marks(recv);
	`}
end

# A scrollbar
# See: https://developer.gnome.org/gtk3/3.2/GtkScrollbar.html
extern class GtkScrollbar `{GtkScrollbar *`}
	super GtkRange

		new (orientation: GtkOrientation, adjustment: GtkAdjustment) `{
		return (GtkScrollbar *)gtk_scrollbar_new(orientation, adjustment);
	`}
end

# A widget that displays a small to medium amount of text
# See: https://developer.gnome.org/gtk3/3.2/GtkLabel.html
extern class GtkLabel `{GtkLabel *`}
	super GtkMisc

	# Create a GtkLabel with text
	new (text: String) import String.to_cstring `{
		return (GtkLabel*)gtk_label_new(String_to_cstring(text));
	`}

	# Set the text of the label
	fun text=(text: String) import String.to_cstring `{
		gtk_label_set_text(recv, String_to_cstring(text));
	`}

	# Returns the text of the label
	fun text: String import NativeString.to_s `{
		return NativeString_to_s((char*)gtk_label_get_text(recv));
	`}

	# Sets the angle of rotation for the label.
	# An angle of 90 reads from from bottom to top, an angle of 270, from top to bottom.
	fun angle=(degre: Float) `{
		gtk_label_set_angle(recv, degre);
	`}

	# Returns the angle of rotation for the label.
	fun angle: Float `{
		return gtk_label_get_angle(recv);
	`}

end

# A widget displaying an image
# See: https://developer.gnome.org/gtk3/3.2/GtkImage.html
extern class GtkImage `{GtkImage *`}
	super GtkMisc

	# Create a GtkImage
	new `{
		return (GtkImage*)gtk_image_new();
	`}

	# Create a GtkImage with text
	new file(filename: String) import String.to_cstring `{
		return (GtkImage*)gtk_image_new_from_file(String_to_cstring(filename));
	`}

	fun pixel_size: Int `{
		return gtk_image_get_pixel_size(recv);
	`}

	fun pixel_size=(size: Int) `{
		gtk_image_set_pixel_size(recv, size);
	`}

	fun clear `{
		gtk_image_clear(recv);
	`}
end

# enum GtkImageType
# Describes the image data representation used by a GtkImage.
# See: https://developer.gnome.org/gtk3/3.2/GtkImage.html#GtkImageType
extern class GtkImageType `{GtkImageType`}
	# There is no image displayed by the widget.
	new empty `{ return GTK_IMAGE_EMPTY; `}

	# The widget contains a GdkPixbuf.
	new pixbuf `{ return GTK_IMAGE_PIXBUF; `}

	# The widget contains a stock icon name.
	new stock `{ return GTK_IMAGE_STOCK; `}

	# The widget contains a GtkIconSet.
	new icon_set `{ return GTK_IMAGE_ICON_SET; `}

	# The widget contains a GdkPixbufAnimation.
	new animation `{ return GTK_IMAGE_ANIMATION; `}

	# The widget contains a named icon.
	new icon_name `{ return GTK_IMAGE_ICON_NAME; `}

	# The widget contains a GIcon.
	new gicon `{ return GTK_IMAGE_GICON; `}
end

# Displays an arrow
# See: https://developer.gnome.org/gtk3/3.2/GtkArrow.html
extern class GtkArrow `{GtkArrow *`}
	super GtkMisc

	new (arrow_type: GtkArrowType, shadow_type: GtkShadowType) `{
		return (GtkArrow *)gtk_arrow_new(arrow_type, shadow_type);
	`}

	fun set(arrow_type: GtkArrowType, shadow_type: GtkShadowType) `{
		gtk_arrow_set(recv, arrow_type, shadow_type);
	`}
end

# A widget that emits a signal when clicked on
# See: https://developer.gnome.org/gtk3/stable/GtkButton.html
extern class GtkButton `{GtkButton *`}
	super GtkBin

	new `{
		return (GtkButton *)gtk_button_new();
	`}

	# Create a GtkButton with text
	new with_label(text: String) import String.to_cstring `{
		return (GtkButton *)gtk_button_new_with_label(String_to_cstring(text));
	`}

	new from_stock(stock_id: String) import String.to_cstring `{
		return (GtkButton *)gtk_button_new_from_stock(String_to_cstring(stock_id));
	`}

	fun text: String `{
		return NativeString_to_s((char *)gtk_button_get_label(recv));
	`}

	fun text=(value: String) import String.to_cstring `{
		gtk_button_set_label(recv, String_to_cstring(value));
	`}

	fun on_click(to_call: GtkCallable, user_data: nullable Object) do
			signal_connect("clicked", to_call, user_data)
	end

end

# A button which pops up a scale
# See: https://developer.gnome.org/gtk3/stable/GtkScaleButton.html
extern class GtkScaleButton `{GtkScaleButton *`}
	super GtkButton

	# const gchar **icons
	new(size: GtkIconSize, min: Float, max: Float, step: Float) `{
		return (GtkScaleButton *)gtk_scale_button_new(size, min, max, step, (const char **)0);
	`}
end

# Create buttons bound to a URL
# See: https://developer.gnome.org/gtk3/stable/GtkLinkButton.html
extern class GtkLinkButton `{GtkLinkButton *`}
	super GtkButton

	new(uri: String) import String.to_cstring `{
		return (GtkLinkButton *)gtk_link_button_new(String_to_cstring(uri));
	`}
end

# A container which can hide its child
# https://developer.gnome.org/gtk3/stable/GtkExpander.html
extern class GtkExpander `{GtkExpander *`}
	super GtkBin

	new(lbl: String) import String.to_cstring `{
		return (GtkExpander *)gtk_expander_new(String_to_cstring(lbl));
	`}

	new with_mnemonic(lbl: String) import String.to_cstring `{
		return (GtkExpander *)gtk_expander_new_with_mnemonic(String_to_cstring(lbl));
	`}

	fun expanded: Bool `{
		return gtk_expander_get_expanded(recv);
	`}

	fun expanded=(is_expanded: Bool) `{
		gtk_expander_set_expanded(recv, is_expanded);
	`}

	fun spacing: Int `{
		return gtk_expander_get_spacing(recv);
	`}

	fun spacing=(pixels: Int) `{
		gtk_expander_set_spacing(recv, pixels);
	`}

	fun label_text: String `{
		return NativeString_to_s((char *)gtk_expander_get_label(recv));
	`}

	fun label_text=(lbl: String) import String.to_cstring `{
		gtk_expander_set_label(recv, String_to_cstring(lbl));
	`}

	fun use_underline: Bool `{
		return gtk_expander_get_use_underline(recv);
	`}

	fun use_underline=(used: Bool) `{
		gtk_expander_set_use_underline(recv, used);
	`}

	fun use_markup: Bool `{
		return gtk_expander_get_use_markup(recv);
	`}

	fun use_markup=(used: Bool) `{
		 gtk_expander_set_use_markup(recv, used);
	`}

	fun label_widget: GtkWidget `{
		return gtk_expander_get_label_widget(recv);
	`}

	fun label_widget=(widget: GtkWidget) `{
		gtk_expander_set_label_widget(recv, widget);
	`}

	fun label_fill: Bool `{
		return gtk_expander_get_label_fill(recv);
	`}

	fun label_fill=(fill: Bool) `{
		gtk_expander_set_label_fill(recv, fill);
	`}

	fun resize_toplevel: Bool `{
		return gtk_expander_get_resize_toplevel(recv);
	`}

	fun resize_toplevel=(resize: Bool) `{
		gtk_expander_set_resize_toplevel(recv, resize);
	`}

end

# An abstract class for laying out GtkCellRenderers
# See: https://developer.gnome.org/gtk3/stable/GtkCellArea.html
extern class GtkComboBox `{GtkComboBox *`}
	super GtkBin

	new `{
		return (GtkComboBox *)gtk_combo_box_new();
	`}

	new with_entry `{
		return (GtkComboBox *)gtk_combo_box_new_with_entry();
	`}

	new with_model(model: GtkTreeModel) `{
		return (GtkComboBox *)gtk_combo_box_new_with_model(model);
	`}

	new with_model_and_entry(model: GtkTreeModel) `{
		return (GtkComboBox *)gtk_combo_box_new_with_model_and_entry(model);
	`}

	new with_area(area: GtkCellArea) `{
		return (GtkComboBox *)gtk_combo_box_new_with_area(area);
	`}

	new with_area_and_entry(area: GtkCellArea) `{
		return (GtkComboBox *)gtk_combo_box_new_with_area_and_entry(area);
	`}

	fun wrap_width: Int `{
		return gtk_combo_box_get_wrap_width(recv);
	`}

	fun wrap_width=(width: Int) `{
		gtk_combo_box_set_wrap_width(recv, width);
	`}

	fun row_span_col: Int `{
		return gtk_combo_box_get_row_span_column(recv);
	`}

	fun row_span_col=(row_span: Int) `{
		gtk_combo_box_set_row_span_column(recv, row_span);
	`}

	fun col_span_col: Int `{
		return gtk_combo_box_get_column_span_column(recv);
	`}

	fun col_span_col=(col_span: Int) `{
		gtk_combo_box_set_column_span_column(recv, col_span);
	`}

	fun active_item: Int `{
		return gtk_combo_box_get_active(recv);
	`}

	fun active_item=(active: Int) `{
		gtk_combo_box_set_active(recv, active);
	`}

	fun column_id: Int `{
		return gtk_combo_box_get_id_column(recv);
	`}

	fun column_id=(id_column: Int) `{
		gtk_combo_box_set_id_column(recv, id_column);
	`}

	fun active_id: String `{
		return NativeString_to_s((char *)gtk_combo_box_get_active_id(recv));
	`}

	fun active_id=(id_active: String) import String.to_cstring `{
		gtk_combo_box_set_active_id(recv, String_to_cstring(id_active));
	`}

	fun model: GtkTreeModel `{
		return gtk_combo_box_get_model(recv);
	`}

	fun model=(model: GtkTreeModel) `{
		gtk_combo_box_set_model(recv, model);
	`}

	fun popup `{
		gtk_combo_box_popup(recv);
	`}

	fun popdown `{
		gtk_combo_box_popdown(recv);
	`}

	fun title: String `{
		return NativeString_to_s((char *)gtk_combo_box_get_title(recv));
	`}

	fun title=(t: String) import String.to_cstring `{
		gtk_combo_box_set_title(recv, String_to_cstring(t));
	`}

	fun has_entry: Bool `{
		return gtk_combo_box_get_has_entry(recv);
	`}

	fun with_fixed: Bool `{
		return gtk_combo_box_get_popup_fixed_width(recv);
	`}

	fun with_fixed=(fixed: Bool) `{
		gtk_combo_box_set_popup_fixed_width(recv, fixed);
	`}
end

# Show a spinner animation
# See: https://developer.gnome.org/gtk3/3.2/GtkSpinner.html
extern class GtkSpinner `{GtkSpinner *`}
	super GtkWidget

	new `{
		 return (GtkSpinner *)gtk_spinner_new();
	`}

	fun start `{
		return gtk_spinner_start(recv);
	`}

	fun stop `{
		return gtk_spinner_stop(recv);
	`}
end

# A "light switch" style toggle
# See: https://developer.gnome.org/gtk3/3.2/GtkSwitch.html
extern class GtkSwitch `{GtkSwitch *`}
	super GtkWidget

	new `{
		 return (GtkSwitch *)gtk_switch_new();
	`}

	fun active: Bool `{
		return gtk_switch_get_active(recv);
	`}

	fun active=(is_active: Bool) `{
		return gtk_switch_set_active(recv, is_active);
	`}
end

# A widget which controls the alignment and size of its child
# https://developer.gnome.org/gtk3/stable/GtkAlignment.html
extern class GtkAlignment `{GtkAlignment *`}
	super GtkBin

	new (xalign: Float, yalign: Float, xscale: Float, yscale: Float) `{
		return (GtkAlignment *)gtk_alignment_new(xalign, yalign, xscale, yscale);
	`}

	fun set (xalign: Float, yalign: Float, xscale: Float, yscale: Float) `{
		gtk_alignment_set(recv, xalign, yalign, xscale, yscale);
	`}

end

# A representation of an adjustable bounded value
# See: https://developer.gnome.org/gtk3/stable/GtkAdjustment.html#GtkAdjustment.description
extern class GtkAdjustment `{GtkAdjustment *`}
end

extern class GdkColor `{GdkColor*`}
	new (color_name: String) import String.to_cstring `{
		GdkColor *color = malloc(sizeof(GdkColor));
		gdk_color_parse(String_to_cstring(color_name), color);
		return color;
	`}
end

extern class GdkRGBA `{GdkRGBA*`}
end

