/*
 * Gestures_Control.pde;
 *
 * Copyright (c) 2011 Jeremy Archer
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import SimpleOpenNI.SimpleOpenNI;

int screenWidth = 1280, screenHeight = 800;

SimpleOpenNI openni;
ArrayList<Person> people;
ArrayList<Target> targets, targetsToAddNextCycle;
PFont monaco, helvetica;
Target fullScreenTarget;

/*
 * Represents a single cursor and hand belonging to a
 * figure on the screen.
 */
class Hand {
    int x, y, z, deltaX, deltaY, deltaZ;
    int grabX, grabY;
    boolean grabbing, visible, isLeftHand;
    Person person;
    Target grabTarget;
    PVector start, direction;
    
    /*
     * Initialize this hand given its sidedness and
     * parent.
     */
    Hand(Person p, boolean isLeft) {
        person = p;
        grabbing = visible = false;
        isLeftHand = isLeft;
        
        x = y = z = grabX = grabY = -1;
        deltaX = deltaY = deltaZ = 0;
        
        start = direction = null;
    }
    
    /*
     * Moves this hand to a new position.
     *
     * Internally, this method handles smoothing,
     * meaning that 
     */
    void moveHand(int newX, int newY, int newZ) {
        x += deltaX = (newX - x + 1) / 2;
        y += deltaY = (newY - y + 1) / 2;
        z += deltaZ = (newZ - z + 1);
        
        /*
         * Check for NaN: for complicated reasons,
         * (1/0) != (1/0).
         */
        if (x != x) x = 0;
        if (y != y) y = 0;
        if (z != z) z = 0;
        
        /*
         * Hide the hand if it is off-screen.
         */
        visible = (x >= 0 && y >= 0 && x < width && y < height);
    }
    
    /*
     * Renders this hand on the current Processing canvas.
     *
     * It will look like a circle with a letter (L or R)
     * attached.
     */
    void draw() {
        if (!visible) return;
        
        noStroke();
        if (grabTarget != null)
            fill(200, 0, 0);
        else
            fill(200, 200, 0);
        ellipse(x - 10, y - 10, 20, 20);
        
        fill(255);
        textFont(helvetica, 60f);
        text(isLeftHand ? "L" : "R", x - 10, y - 10);
    }
    
    /*
     * Pulls the latest data from the SimpleOpenNI instance.
     */
    void updateFromNI() {
        PVector projYourHand = new PVector(), yourHand = new PVector();
        PVector projYourTorso = new PVector(), yourTorso = new PVector();
        
        /*
         * Get the position of the hand, as a PVector.
         *
         * (c1 represents the certainty of that position.)
         */
        float c1 = openni.getJointPositionSkeleton(
            /* user ID */     person.getID(),
            /* joint */       isLeftHand ? SimpleOpenNI.SKEL_LEFT_HAND : SimpleOpenNI.SKEL_RIGHT_HAND,
            /* destination */ projYourHand
        );
        
        /*
         * Get the position of the torso, as a PVector.
         *
         * (c2, as above, represents the certainty.)
         */
        float c2 = openni.getJointPositionSkeleton(
            /* user ID */     person.getID(),
            /* joint */       SimpleOpenNI.SKEL_TORSO,
            /* destination */ projYourTorso
        );
        
        /*
         * KLUGE: If we're fairly uncertain about either vector,
         * hide this hand.
         * 
         * Since the NI documentation is fairly sparse in this
         * manner, this factor is pretty arbitrary.
         */
        if (c1 <= 1f || c2 <= 1f) {
            visible = false;
            return;
        }
        
        /*
         * Convert the perspective vectors (angle and distance) to
         * real-world (x, y, z) vectors.
         */
        openni.convertProjectiveToRealWorld(projYourTorso, yourTorso);
        openni.convertProjectiveToRealWorld(projYourHand, yourHand);
        
        /*
         * Scale the vectors arbitrarily to the screen size.
         * They are currently in milimeters, so we need to
         * convert them to screen (pixel) co-ordinates.
         * 
         * Here, we're using a grab box of four meters wide,
         * two meters tall, and about half a meter deep.
         */
        int newX = (int)(((yourHand.x - yourTorso.x + 2000.0) / 4000.0) * width);
        int newY = (int)(((yourHand.y - yourTorso.y + 1000.0) / 2000.0) * height);
        int newZ = (int)(((yourTorso.z - yourHand.z) / 450.0) * 100.0);
        
        /*
         * Move the hand to this new position.
         */
        moveHand(newX, newY, newZ);
    }
    
    /*
     * Detect if this hand is intersecting something on the hit image
     * in the blue-channel.
     * 
     * The "hit image," in this case, is an image with all the objects
     * rendered in a flat, per-object color, so that we can simply see
     * the color at a certain (x, y)-location to see what object lies
     * there.
     */
    public int intersect(PImage hitTestImage) {
        /*
         * Disable if we're invisible; i.e. off-screen.
         * 
         * That's why we don't need a conditional here.
         */
        if (!visible) return -1;
        
        /*
         * A few things are going on here:
         *
         * First, the image is scaled down to 10%, meaning that we need
         * to scale both x and y by 10. We also need to linearize them,
         * (in row-major order). Then the result, which is a color, may
         * have some alpha components, so we get rid of them and extract
         * the blue component.
         */
        int value = hitTestImage.pixels[(x / 10) + (y / 10) * (width / 10)] & 0xff;
        
        /*
         * The blue-component value of zero is black (#000), so we need
         * to shift this guy down by one so that #000001 maps to 0 and
         * #000000 maps to -1 (no intersection).
         */
        return value - 1;
    }
    
    /*
     * Detect if this hand is intersecting something on the hit image
     * in the green-channel.
     * 
     * The "hit image," in this case, is an image with all the objects
     * rendered in a flat, per-object color, so that we can simply see
     * the color at a certain (x, y)-location to see what object lies
     * there.
     */
    public int intersectGreen(PImage hitTestImage) {
        /*
         * Disable if we're invisible; i.e. off-screen.
         * 
         * That's why we don't need a conditional here.
         */
        if (!visible) return -1;
        
        /*
         * A few things are going on here:
         *
         * First, the image is scaled down to 10%, meaning that we need
         * to scale both x and y by 10. We also need to linearize them,
         * (in row-major order). Then the result, which is a color, may
         * have some alpha components, so we get rid of them and extract
         * the green component.
         */
        int value = (hitTestImage.pixels[(x / 10) + (y / 10) * (width / 10)] >> 8) & 0xff;
        
        /*
         * The blue-component value of zero is black (#000), so we need
         * to shift this guy down by one so that #000001 maps to 0 and
         * #000000 maps to -1 (no intersection).
         */
        return value - 1;
    }
    
    /*
     * Mark this hand as having hovered over another object, given
     * the target's ID and secondary (green-component) color index.
     * 
     * If t is null, mark this object as not grabbing anything.
     */
    public void grab(Target t, int secondaryIndex) {
        /*
         * Record this object
         */
        grabTarget = t;
        
        /*
         * If given a new target, tell that object to begin
         * showing hover feedback.
         */
        if (t != null)
            t.takeHoverDataFrom(this, secondaryIndex);
    }
    
    /*
     * Sets the target given the rendered hit image and numbered targets.
     * 
     * The index of each object will be encoded in the blue-channel of the
     * PImage, so that, for example: object 0 (the first object in the list),
     * will be encoded as #000001; object 1 as #000002; et. al.
     */
    public void setTargetFrom(PImage hitTestImage, ArrayList<Target> targets) {
        /*
         * If we're already hovering over something, unregister us from the
         * object. If it turns out that we are still hovering over it with
         * both hands, the Person class will register us as having grabbed
         * it.
         */
        if (grabTarget != null)
            grabTarget.setGrabbedBy(null);
        
        /*
         * Extract the blue and green indices from the hit image.
         */
        int index = intersect(hitTestImage);
        int secondaryIndex = intersectGreen(hitTestImage);
        
        /*
         * If we're hovering over something, mark it as having been hovered
         * over.
         */
        if (index == -1) grab(null, 0);
        else grab(targets.get(index), secondaryIndex);
    }
    
    /*
     * Gets the target we're currently hovering over.
     */
    public Target getGrabTarget() {
        return grabTarget;
    }
    
    /*
     * Returns whether this hand is on-screen.
     */
    public boolean getIsVisible() {
      return visible;
    }
    
    /*
     * Returns the X-coordinate (in screen pixels) of this hand.
     */
    public int getX() {
        return x;
    }
    
    /*
     * Returns the Y-coordinate (in screen pixels) of this hand.
     */
    public int getY() {
        return y;
    }
    
    /*
     * Returns the Z-coordinate of this hand.
     * 
     * In practice, this will usually be in the range [-150.0,
     * +150.0], but there isn't a defined rectangle like for x
     * and y.
     */
    public int getZ() {
        return z;
    }
}

/*
 * Controlling class for a person with two hands.
 */
class Person {
    Hand left, right;
    int userID;
    Target grabTarget;
    
    /*
     * Initialize this person given their ID in OpenNI.
     */
    public Person(int id) {
        left = new Hand(this, true);
        right = new Hand(this, false);
        userID = id;
    }
    
    /*
     * Return the internal OpenNI identifier.
     */
    public int getID() {
        return userID;
    }
    
    /*
     * Returns the left hand.
     */
    public Hand getLeftHand() { return left; }
    
    /*
     * Returns the left hand.
     */
    public Hand getRightHand() { return right; }
    
    /*
     * Update the current grabbing / hovering status, given the hit image
     * and list of targets.
     * 
     * The hit image is a rendered image with the various targets rendered
     * as a silhouette in a flat color. The first object in the array is
     * in color #000001, the second in #000002, and so on.
     */
    public void updateGrabbing(PImage hitTestImage, ArrayList<Target> targets) {
        /*
         * Update the hovering status for both hands.
         */
        left.setTargetFrom(hitTestImage, targets);
        right.setTargetFrom(hitTestImage, targets);
        
        /*
         * If we're hovering over the same object with both hands,
         * then mark the target as having been grabbed by us.
         */
        if (left.getGrabTarget() == right.getGrabTarget() && (left.getGrabTarget() != null))
            left.getGrabTarget().setGrabbedBy(this);
    }
    
    /*
     * Gets the average X position of the two hands.
     */
    public int getAverageX() {
        return (getLeftHand().getX() + getRightHand().getX()) / 2;
    }
    
    /*
     * Gets the average Y position of the two hands.
     */
    public int getAverageY() {
        return (getLeftHand().getY() + getRightHand().getY()) / 2;
    }
    
    /*
     * Gets the angle [-pi, +pi] between the two hands.
     */
    public float getHandAngle() {
        return atan2(getRightHand().getY() - getLeftHand().getY(),
                     getRightHand().getX() - getLeftHand().getX());
    }
    
    /*
     * Gets the distance between both hands.
     */
    public float getGrabRadius() {
        float dx = getRightHand().getY() - getLeftHand().getY(),
              dy = getRightHand().getX() - getLeftHand().getX();
        
        return (float)Math.sqrt(dx*dx + dy*dy);
    }
}

/*
 * Represents a grabbable object on the screen.
 */
interface Target {
    /*
     * Renders this object as a silhouette onto the PGraphics object
     * given the value the blue component should have.
     */
    void drawHitRegion(PGraphics g, int blueComponent);
    
    /*
     * Renders this object in full color.
     */
    void draw();
    
    /*
     * Sets this object as having been grabbed by the specified
     * person. This method will be called a lot (every frame)
     * so it should do little more than set a variable.
     */
    void setGrabbedBy(Person p);
    
    /*
     * Moves this object to the new location.
     */
    void moveTo(int x, int y);
    
    /* 
     * Rotates this object to the specified angle.
     */
    void rotateTo(float angleInRadians);
    
    /*
     * Updates the position and rotation of the object given
     * the person grabbing it.
     */
    void updateGrabbing();
    
    /*
     * Update the UI to show feedback to being hovered over by
     * the specified hand. This method is also passed the
     * green component of the color the hand is hovering over.
     */
    void takeHoverDataFrom(Hand h, int secondaryIndex);
}

/*
 * Represents a target that is nested inside another.
 */
interface SubTarget {
    /* 
     * Renders this object as a silhouette. The PGraphics will
     * already be initialized with the proper color.
     */
    void drawHitRegion(PGraphics g);
    
    /*
     * Renders this object in full color.
     */
    void draw();
    
    /*
     * Marks this object as currently being hovered over.
     */
    void hoverOver();
    
    /* 
     * Updates this object given the current visibility of this
     * SubTarget.
     */
    void updateHovering(boolean enabled);
}

/*
 * Represents an abstract rectangular target.
 *
 * By default, this class only draws a grey rectangle on the
 * screen, but supports SubTargets, rotation and movement.
 * 
 * Most other Targets are subclasses of this one.
 */
class Rectangle implements Target {
    int x, y, w, h;
    float rotationAngle;
    Person grabbedBy;
    ArrayList<SubTarget> subTargets;
    
    /*
     * Initializes this rectangle with the default size, 500x300,
     * and places it in the center of the screen.
     */
    public Rectangle() {
        w = 500;
        h = 300;
        x = (width - w) / 2;
        y = (height - h) / 2;
        rotationAngle = 0.0f;
        grabbedBy = null;
        subTargets = new ArrayList<SubTarget>();
    }
    
    /*
     * Returns true if this object can be bumped into full-screen
     */
    boolean canBeMadeFullScreen() {  // meant to be overriden.
        return false;
    }
    
    /*
     * Renders this object in color. The coordinate system will
     * already have been shifted and rotated so that the object
     * should be placed to the right and below (0, 0).
     * 
     * Subclasses note: this method renders SubTargets. If you
     * intend to replace or override this method, you must manually
     * render all SubTarget instances in this class, like so:
     * 
     *   ...
     *   
     *   void drawTarget() {
     *     
     *     ...
     *     
     *     for (SubTarget target : subTargets) {
     *       target.draw();
     *     }
     *   }
     *   
     *   ...
     */
    void drawTarget() { // meant to be overriden.
        if (grabbedBy != null)
            stroke(200, 0, 0);
        else
            stroke(200, 200, 0);
        
        strokeWeight(5);
        fill(50);
        
        rect(0, 0, w, h);
        
        for (SubTarget target : subTargets) {
            target.draw();
        }
    }
    
    /*
     * Renders this target as a silhouette onto the image buffer
     * instance. The coordinate system will already have been
     * shifted and rotated so that the object should be placed
     * to the right and below (0, 0).
     * 
     * Subclasses note: this method renders SubTargets. If you
     * intend to replace or override this method, you must manually
     * render all SubTarget instances in this class, like the below.
     * 
     * Likewise, before rendering, you must ensure that all objects
     * are drawn in the proper color:
     * 
     *   ...
     *   void drawTargetHitRegions(PGraphics g, int blueComponent) {
     *     g.fill(0, 0, blueComponent);
     *     
     *     ...
     * 
     *     for (int i = 0; i < subTargets.size(); i++) {
     *       g.fill(0, (i + 1), blueComponent);
     *       subTargets.get(i).drawHitRegion(g);
     *     }
     *   }
     *   ...
     */
    void drawTargetHitRegions(PGraphics g, int blueComponent) { // meant to be overriden.
        g.fill(0, 0, blueComponent);
        g.rect(0, 0, w, h);
        
        for (int i = 0; i < subTargets.size(); i++) {
            g.fill(0, (i + 1), blueComponent);
            subTargets.get(i).drawHitRegion(g);
        }
    }
    
    /*
     * Adds a SubTarget to this list.
     */
    void addSubTarget(SubTarget tar) {
        subTargets.add(tar);
    }
    
    /*
     * Draws this object in silhouette form in a color with the
     * specified blue component, as specified in the interface.
     */
    void drawHitRegion(PGraphics g, int blueComponent) {
        /* 
         * Determine if the entire screen has a single component.
         */
        if (fullScreenTarget != null) {
            /* 
             * If we're full-screen, render the entire screen as
             * the same color. It's wasteful, but cycles are
             * plentiful nowadays.
             */
           if (fullScreenTarget == this) {
               /*
               * Transform our co-ordiante system and render.
               */
               g.pushMatrix();
               g.fill(0, 0, blueComponent);
               g.rect(0, 0, width, height);
               g.translate(width / 2, height / 2);
               g.scale(Math.min(((float)width) / w, ((float)height) / h));
               g.translate(-w / 2, -h / 2);
               
               drawTargetHitRegions(g, blueComponent);
               g.popMatrix();
           }
        } else {
            /*
             * Transform our co-ordinate system and render.
             */
            g.pushMatrix();
            g.translate(x, y);
            g.translate(w / 2, h / 2);
            
            g.rotate(rotationAngle);
            
            /*
             * If we're grabbing, increase the size of the object
             * to make it easier to grip.
             */
            if (grabbedBy != null) g.scale(1.5);
            
            g.translate(-w / 2, -h / 2);
            drawTargetHitRegions(g, blueComponent);
            
            g.popMatrix();
        }
    }
    
    /*
     * Renders this object in full-color.
     */
    void draw() {
        /*
         * Determine whether one component is blocking the
         * entire screen.
         */
        if (fullScreenTarget == this) {
            /*
             * If we're in full-screen, simply transform
             * and render.
             */
            pushMatrix();
            translate(width / 2, height / 2);
            scale(Math.min(((float)width) / w, ((float)height) / h));
            translate(-w / 2, -h / 2);
            drawTarget();
            popMatrix();
            
            /*
             * Retransform and put an axis through both hands to indicate
             * that distance is how a full-screen view is maintained.
             */
            pushMatrix();
            strokeWeight(1);
            stroke(255, 255, 255, 50);
            noFill();
            
            translate(grabbedBy.getAverageX(), grabbedBy.getAverageY());
            rotate(grabbedBy.getHandAngle());
            
            ellipse(0, 0, 0.6 * width, 0.6 * width);
            line(-width * 10, 0, width * 10, 0);
            line(0, -height * 10, 0, height * 10);
            
            popMatrix();
        } else if (fullScreenTarget == null) {
            /*
             * If no target is in full-screen, then transform and render
             * in the normal place.
             */
            pushMatrix();
            translate(x + w / 2, y + h / 2);
            rotate(rotationAngle);
            translate(-w / 2, -h / 2);
            drawTarget();
            
            /*
             * If we've been grabbed, render an overlay of crosshairs and 
             * an outer radius.
             */
            if (grabbedBy != null) {
                translate(w / 2, h / 2);
                
                strokeWeight(1);
                stroke(255, 255, 255, 50);
                noFill();
                line(-width * 10, 0, width * 20, 0);
                line(0, -height * 10, 0, height * 20);
                ellipse(0, 0, 100, 100);
                ellipse(0, 0, 40, 40);
            }
            
            popMatrix();
        }
        
        /*
         * Update the status of all subtargets.
         *
         * Pass true if this subtarget is visible.
         */
        for (SubTarget tar : subTargets) {
            tar.updateHovering((grabbedBy == null && fullScreenTarget == null) ||
                fullScreenTarget == this);
        }
    }
    
    /*
     * Mark this target as having been grabbed.
     */
    void setGrabbedBy(Person p) {
        grabbedBy = p;
    }
    
    /*
     * Update hovering data from the given hand and highlight
     * the the target.
     */
    void takeHoverDataFrom(Hand p, int greenComponent) {
        if (greenComponent != -1) {
            SubTarget tar = subTargets.get(greenComponent);
            tar.hoverOver();
        }
    }
    
    /*
     * Moves the rectangle to the specified x and y.
     */
    void moveTo(int newX, int newY) {
        x = newX - w / 2;
        y = newY - h / 2;
    }
    
    /*
     * Rotates this rectangle to the specified angle from 
     * the horizontal.
     */
    void rotateTo(float angleInRadians) {
        rotationAngle = angleInRadians;
    }
    
    /*
     * Updates the position and rotation of this object given
     * the position of the grabbing hand.
     */
    void updateGrabbing() {
        if (grabbedBy != null && fullScreenTarget == null) {
            /*
             * If no one is full screen, then move and rotate
             * this block.
             */
            moveTo(grabbedBy.getAverageX(), grabbedBy.getAverageY());
            rotateTo(grabbedBy.getHandAngle());
            
            /*
             * If the hands are close enough together, pop into
             * full screen mode.
             */
            if (grabbedBy.getGrabRadius() < 100) {
                fullScreenTarget = this; 
            }
            
        } else if (fullScreenTarget == this) {
            /*
             * If we're out of full screen and the hands are too
             * far apart, pop out of full screen.
             */
            if (grabbedBy == null || grabbedBy.getGrabRadius() > 0.6 * width) {
                fullScreenTarget = null;
            }
        }
    }
}

/*
 * A movable view of NI's depth image, colored for calibration.
 */
class SceneViewTarget extends Rectangle {
    /*
     * By default, this view is half the pixel width of NI's 
     * scene image.
     */
    SceneViewTarget() {
        w = openni.sceneWidth() / 2;
        h = openni.sceneHeight() / 2;
        x = width - w;
        y = height - h;
    }
    
    /*
     * This can be made full-screen. When in full-screen
     * mode, it displays a four-up view of IR, the scene,
     * depth and RGB information.
     */
    boolean canBeMadeFullScreen() {
        return true;
    }
    
    /*
     * Renders the NI scene image, with overlays for the
     * arms and torso.
     */
    void drawSceneView() {
        rect(0, 0, w, h);
        
        image(openni.sceneImage(), 0, 0, w, h);
        
        if (grabbedBy != null)
            stroke(200, 0, 0);
        else
            stroke(200, 200, 0);
        
        strokeWeight(5);
        
        strokeWeight(10);
        stroke(200, 200, 0);
        noFill();
        
        scale(0.5, 0.5);
        
        for (Person p : people) {
            openni.drawLimb(p.getID(), SimpleOpenNI.SKEL_LEFT_ELBOW, SimpleOpenNI.SKEL_LEFT_HAND);
            openni.drawLimb(p.getID(), SimpleOpenNI.SKEL_RIGHT_ELBOW, SimpleOpenNI.SKEL_RIGHT_HAND);
            
            openni.drawLimb(p.getID(), SimpleOpenNI.SKEL_LEFT_ELBOW, SimpleOpenNI.SKEL_TORSO);
            openni.drawLimb(p.getID(), SimpleOpenNI.SKEL_RIGHT_ELBOW, SimpleOpenNI.SKEL_TORSO);
        }
    }
    
    /*
     * Renders this control.
     */
    void drawTarget() {
        /*
         * Draw the scene view.
         */
        if (fullScreenTarget == this) {
            /*
             * Draw the scene view in the top left.
             */
             
            pushMatrix();
            scale(0.5, 0.5);
            drawSceneView();
            popMatrix();
            
            /*
             * Render the IR, depth, and RGB images. I don't
             * believe that IR and RGB can be seen at the same
             * time for technical reasons.
             */
            if (openni.irImage() != null)
                image(openni.irImage(), w / 2, 0, w / 2, h / 2);
            image(openni.depthImage(), 0, h / 2, w / w, h / 2);
            
            if (openni.rgbImage() != null)
                image(openni.rgbImage(), w / 2, h / 2, w / 2, h / 2);
        } else {
            /*
             * In regular mode, just render the scene.
             */
            pushMatrix();
            drawSceneView();
            popMatrix();
        }
    }
}

/*
 * Represents a textual label that can be placed
 * and moved.
 */
class RefrigeratorMagnet extends Rectangle {
    String label;
    
    /*
     * Initialize this widget given the string
     * to display. It will be placed randomly on
     * the screen (with caveats -- can you see
     * why?) and with enough width to display
     * the message.
     */
    RefrigeratorMagnet(String s) {
        textFont(helvetica,90);
        
        w = (int)textWidth(s) + 20;
        h = 100;
        x = (int)random(width - w);
        y = (int)random(height - h);
        
        label = s;
    }
    
    /*
     * Renders the magnet. It will be drawn in
     * Helvetica with a colored border, depending
     * on its status.
     */
    void drawTarget() {
        if (grabbedBy != null)
            stroke(200, 0, 0);
        else
            stroke(200, 200, 0);
        
        strokeWeight(5);
        fill(10);
        
        rect(0, 0, w, h);
        
        fill(255);
        textFont(helvetica, 90);
        text(label, 10, 80);
        
        for (SubTarget target : subTargets) {
            target.draw();
        }
    }
}

/*
 * A collection of key widgets that allow the
 * user to type letters and make textual
 * "refrigerator magnets," as above.
 */
class KeyboardTarget extends Rectangle {
    /*
     * The keys were chosen this way based on
     * relative word frequency in English: the
     * most common words are in the center, which
     * (theoretically) makes it more accessible.
     * 
     * Some special characters: the at-sign ("@"),
     * represents "enter," or "newline;" the back-
     * chevron ("<") represents "backspace" or
     * delete, and the space represents "no
     * button."
     */
   String topRow = "JFDWK@",
       secondRow = "GNIRM<", 
        thirdRow = "LTEOU ",
        forthRow = "YSAHV ",
        fifthRow = "XPCBQZ";
   
   String letters;
   
   /*
    * Initialize this keyboard at a size of 600x600,
    * so that each key gets 100x100.
    */
   KeyboardTarget() {
       x = y = 0;
       w = 600;
       h = 600;
       letters = "";
       
       String[] rows = { topRow, secondRow, thirdRow, forthRow, fifthRow };
       
       /*
        * Loop through and create buttons for each key.
        */
       for (int i = 0; i < 6; i += 1) {
           for (int j = 0; j < 5; j += 1) {
               if (rows[j].charAt(i) != ' ') {
                   addSubTarget(new ExplodingButton (
                       /* location and size */ i * 100, j * 100 + 100, 90, 90,
                       /* label */             rows[j].substring(i, i + 1),
                       /* parent */            this
                   ));
               }
           }
       }
   }
   
   /*
    * Draws the containing rectangle and renders
    * the keys for this keyboard.
    */
   void drawTarget() {
       /*
        * Render a border around the keys that is colored
        * based on text-entry status.
        */
       if (grabbedBy != null)
           stroke(200, 0, 0);
       else
           stroke(200, 200, 0);
        
       strokeWeight(5);
       fill(10, 0, 0);
       
       rect(0, 0, w, h);
       
       /*
        * Render the keys.
        */
       for (SubTarget target : subTargets) {
           target.draw();
       }
       
       /*
        * Display the current text entered.
        */
       fill(255);
       textFont(helvetica, 90);
       text(letters, 10, 80);
   }
   
   /*
    * Handles the entry of a single character.
    * 
    * 
    * 
    */
   void typeLetter(String letter) {
       if (letter.equals("@")) {
           /*
            * As above, an at-sign represents "enter," and
            * creates a "refrigerator magnet" containing the
            * current text entered.
            */
           
           targetsToAddNextCycle.add(new RefrigeratorMagnet(letters));
           
           letters = "";
       } else if (letter.equals("<")) {
           /*
            * Likewise, a back-chevron ("<") deletes the
            * previous character entered, if there is one.
            */
           
           if (!letters.equals("")) {
               letters = letters.substring(0, letters.length() - 1);
           }
       } else {
           /* 
            * Anything else is simply appended to the buffer.
            */
           
           letters += letter;
       }
   }
}

/*
 * This flamboyantly-named class represents a single
 * key on the keyboard.
 * 
 * The way this works, in practice, is that hovering
 * over a single key gradually causes it to "heat up"
 * until it "pops" and enters the letter into the
 * keypad.
 */
class ExplodingButton implements SubTarget {
    int x, y, w, h;
    float powerLevel;
    boolean hoveredOver;
    String letter;
    KeyboardTarget parent;
    
    /*
     * Creates a new key given its position relative
     * to its container and letter to display.
     */
    ExplodingButton(int newX, int newY, int newW, int newH,
      String newLetter, KeyboardTarget t) {
        x = newX;
        y = newY;
        w = newW;
        h = newH;
        powerLevel = 0.0;
        hoveredOver = false;
        letter = newLetter;
        parent = t;
    }
    
    /*
     * Draws a silhouette: in this case, a rectangle.
     */
    void drawHitRegion(PGraphics g) {
        g.noStroke();
        g.rect(x, y, w, h);
    }
    
    /*
     * Renders this key for visual presentation.
     * 
     * Importantly, there is visual feedback of
     * the "power level" (really more like "heat")
     * so that the user "feels" the button becoming
     * hotter up to the point of creating the
     * letter. Why programmers are sterotypically
     * immature I have no idea.
     */
    void draw() {
        fill((powerLevel   / 100.0 * 0.9 + 0.1) * 255.0, 0, 0, 100);
        stroke((powerLevel / 100.0 * 0.9 + 0.1) * 255.0, 0, 0, 150);
        strokeWeight(10);
        rect(x, y, w, h);
        
        fill(255);
        textFont(helvetica, h * 0.8);
        text(letter, x + (w - textWidth(letter)) / 2, y + h * 0.8);
    }
    
    /*
     * Marks this key as having been hovered over
     * within the last frame.
     */
    void hoverOver() {
        hoveredOver = true;
    }
    
    /*
     * Update the heat of the button.
     * 
     * The button heats up much faster
     * than it cools down, because that
     * somehow feels more natural.
     */
    void updateHovering(boolean enabled) {
        if (enabled && hoveredOver) {
            powerLevel += 8.0;
        } else {
            powerLevel -= 2.0;
        }
        
        if (powerLevel > 100.0) {
            parent.typeLetter(letter);
            powerLevel = 0;
        }
        
        powerLevel = (float)(max(0, powerLevel));
        
        hoveredOver = false;
    }
    
    /*
     * Returns the current power-level
     * to indicate how close this key
     * is to producing a keypress.
     */
    float getPowerLevel() {
        return powerLevel;
    }
}

void setup() {
    size(screenWidth, screenHeight);
    
    openni = new SimpleOpenNI(this);
    openni.setMirror(true);
    openni.enableScene();
    openni.enableDepth();
    openni.enableUser(SimpleOpenNI.SKEL_PROFILE_ALL);
    openni.enableHands();
    openni.enableIR();
    
    people = new ArrayList<Person>();
    targets = new ArrayList<Target>();
    targetsToAddNextCycle = new ArrayList<Target>();
    
    targets.add(new SceneViewTarget());
    targets.add(new KeyboardTarget());
    
    monaco = loadFont("Monaco.vlw");
    helvetica = loadFont("Helvetica-Bold-48.vlw");
}

/*
 * OpenNI call-back for whenever a person enters the
 * view of the camera.
 */
void onNewUser(int userID) {
    System.out.println("New User: " + userID + "; start pose detection!");
    
    openni.startPoseDetection("Psi", userID);
    
    people.add(new Person(userID));
}

/*
 * OpenNI call-back for whenever a person leaves the
 * view of the camera.
 */
void onLostUser(int userID) {
    System.out.println("Lost User: " + userID);
    
    /*
     * Remove the person from the list of people.
     */
    int foundIndex = -1;
    
    for (int i = 0; i < people.size(); i++) {
        if (people.get(i).getID() == userID) {
            foundIndex = i;
            break;
        }
    }
    
    people.remove(foundIndex);
}

/*
 * Called whenever a user has successfully been calibrated.
 */
void onEndCalibration(int userID, boolean successful) {
    System.out.println("Calibrated User ID : " + userID + " successful : " + successful);
    
    if (successful) {
        /*
         * Wahoo! Calibration successful.
         */
        openni.startTrackingSkeleton(userID);
    } else {
        /*
         * Let's retry pose detection and hopefully they'll
         * get it right.
         */
        openni.startPoseDetection("Psi", userID);
    }
}

/*
 * Called whenever the person makes the Psi pose successfully.
 */
void onStartPose(String pose, int userID) {
    println("onStartPose - userID: " + userID + "; pose = " + pose);
    
    /*
     * Begin calibrating the sensor from their skeleton.
     */
    openni.stopPoseDetection(userID);
    openni.requestCalibrationSkeleton(userID, true);
}

void draw() {
    /* render hit region */
    PGraphics miniRender = createGraphics(width / 10, height / 10, JAVA2D);
    miniRender.beginDraw();
    miniRender.scale(0.1);
    miniRender.noSmooth();
    miniRender.fill(0);
    miniRender.rect(0, 0, miniRender.width, miniRender.height);
    
    for (int i = 0; i < targets.size(); i++) {
        miniRender.fill(color(250, 0, i + 1));
        miniRender.noStroke();
        targets.get(i).drawHitRegion(miniRender, (i + 1));
    }
    
    miniRender.endDraw();
    miniRender.loadPixels();
    
    /* pull data from OpenNI */
    openni.update();
    
    for (Person p : people) {
        p.left.updateFromNI();
        p.right.updateFromNI();
        p.updateGrabbing(miniRender, targets);
    }
    
    /* handle grabbing */
    
    for (Target t : targets) {
        t.updateGrabbing();
    }
    
    /* move new targets into the list */
    
    for (Target t : targetsToAddNextCycle) {
        targets.add(t);
    }
    targetsToAddNextCycle.clear();
    
    /* begin drawing code */
    
    background(0);
    
    /* render normal drawing */
    for (Target t : targets) {
        t.draw();
    }
    
    /* render hands */
    for (Person p : people) {
        p.left.draw();
        p.right.draw();
    }
}