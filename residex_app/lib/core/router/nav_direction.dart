 /// Tracks the direction of the next navigation action.
 /// Set by bottom nav bars before calling context.go().
 /// Read (and reset) by buildPageWithSlideTransition.
 class NavDirection {
   /// true  → new page enters from the RIGHT (default, also used for all push nav)
   /// false → new page enters from the LEFT
   static bool slideFromRight = true;
 }