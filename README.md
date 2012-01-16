Common Report: Next-Generation UIs with Microsoft's Kinect
===

About
---

First, _what is it_? Well, this as-of-yet-unnamed project is basically an application of the fantastic [SimpleOpenNI][simple-openni] project to Microsoft's [Kinect][kinect-site]. It enables the user to make hand gestures in the view of the camera and interact with the software in a more user-friendly manner (see the [video][kinect-demo-video] for details).

[simple-openni]: http://code.google.com/p/simple-openni/
[kinect-site]: http://www.xbox.com/en-US/kinect

Note that thanks go to the University of Chicago Laboratory Schools and particularly Baker Franke for hardware support and logistics and, specifically from the latter, a fantastic six years of mentorship. Credit goes also to Sam Reynolds and the nerds of UH 202 for their suggestions and support.

Video
----------

Here's a [video][kinect-demo-video] demonstrating the basic sorts of things I've implemented. Due to technical glitches at the time of its filming, the video is twice as fast as usual. Nonetheless, there's several highlights to the movie: OpenNI calibration; full-screen widgets; the infrared view; moving widgets; text entry; and special command modules.

[kinect-demo-video]: http://vimeo.com/33249708

Installation
---

Installing this software is unfortunately a bit tricky. My code, `Gestures_Control.pde` is fairly straightforward, but requires that SimpleOpenNI be installed (an [installation guide][simple-open-ni-install] is available on their project site). Once the install completes, I'd highly recommend testing SimpleOpenNI with a few of the demonstration programs included in the installation before trying my code. They include more debugging information and are likely to be more up-to-date.

Once you do, create a new sketch in Processing entitled Gestures_Control (you can't put spaces in project names) and copy Gestures_Control.pde and the contents of the data/ directory from this project into the new sketch. Be sure to replace the existing Processing.org source in Gestures_Control.pde. Once you've done that, adjust the screen-resolution at the top of the file to match your monitor and click "Presentation Mode" in the menubar.

[simple-open-ni-install]: [http://code.google.com/p/simple-openni/wiki/Installation]

Playing With It
---

In my experience, the calibration phase is always the most difficult. You need to have your entire body visible in the scene view (the little box with the figures in the lower-right-hand corner), and your arms must be placed at symmetric right-angles to your head, as in the figure below:

                  
    +      /    \      +
    ++     |.  .|     ++
    |      \  - /      |
    |       |  |       |
    +_____/------\_____+
         |    |_|  /
         |        |
         |        |
         \        /
         |        |
         ==========
         |        |
         |   / |  |
         |  |  |  |
         |  |  |  |
         |  |  |  |
         ____  ____
         |  |  |   |

Try to be as still as you can, and try to match the picture as well as possible. It's unclear what works, but removing jackets and backpacks seems to help, as does avoiding touching other objects while in view of the camera. Try to calibrate yourself from the camera view: your arms should be orthogonal relative to the Kinect, not necessarily by "feeling."

Technical Comments
====

Overall
---

The code comes in three parts, all in one file. The first, a series of class definitions, including: `Person`, `Hand`, the personal control managers; `Target`, `SubTarget` and their implementations, essentially the widgets accessible through the interface; and the various callbacks from Processing.org and OpenNI that connect the logic from the classes to the real-world.

Targets
---

More specifically, the scene is comprised as a series of movable widgets (`Target`'s) on the screen. Anything with a yellow border or that can be moved is a widget. They handle drawing and the creating of hit rectangles, detailed below. They also maintain state, meaning that they keep track of where they are on the screen.

All `Target` instances are subclasses of the `Rectangle` class. That class handles motion, full-screen mode, and rotation, meaning that none of the other classes need to keep track of those things.

SubTargets
---

The keypad in particular needs to store all the keys that it wishes to display, and to do that it creates a `SubTarget` representing each key. That key knows how close it is to triggering a keystroke,
so that when that threshold is reached it knows to tell the keyboard to enter a letter. Most other widgets aren't quite as complex, however, so the entire drawing code is in a single method.

Hit-Testing
---

There are a few things that aren't clear from the code. First is the way it handles object collision detection, namely that between the hands and the rendered objects. Since I really didn't want to handle the linear algebra to solve it via conditionals (dot-products, in essence), I simply had each `Target` render 

License
===

A standard MIT license; from `license.md`:

> Copyright (c) 2011 Jeremy Archer
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

Happy Holidays,

Jeremy Archer