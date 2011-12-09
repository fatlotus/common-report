import SimpleOpenNI.*;
import java.io.*;

SimpleOpenNI openni;
ArrayList<Person> people;
ArrayList<Target> targets, targetsToAddNextCycle;
PFont monaco, helvetica;
Target fullScreenTarget;

class Hand {
    int x, y, z, deltaX, deltaY, deltaZ;
    int grabX, grabY;
    boolean grabbing, visible, isLeftHand;
    Person person;
    Target grabTarget;
    PVector start, direction;
    
    public Hand(Person p, boolean isLeft) {
        person = p;
        grabbing = visible = false;
        isLeftHand = isLeft;
        
        x = y = z = grabX = grabY = -1;
        deltaX = deltaY = deltaZ = 0;
        
        start = direction = null;
    }
    
    void moveHand(int newX, int newY, int newZ) {
        x += deltaX = (newX - x + 1) / 2;
        y += deltaY = (newY - y + 1) / 2;
        z += deltaZ = (newZ - z + 1);
        
        if (x != x) x = 0;
        if (y != y) y = 0;
        if (z != z) z = 0;
               
        visible = (x >= 0 && y >= 0 && x < width && y < height);
    }
    
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
    
    void updateFromNI() {
        PVector projYourHand = new PVector(), yourHand = new PVector();
        PVector projYourTorso = new PVector(), yourTorso = new PVector();
        
        float c1 = openni.getJointPositionSkeleton(person.getID(),
            isLeftHand ? SimpleOpenNI.SKEL_LEFT_HAND : SimpleOpenNI.SKEL_RIGHT_HAND, projYourHand);
        float c2 = openni.getJointPositionSkeleton(person.getID(), SimpleOpenNI.SKEL_TORSO, projYourTorso);
        
        if ((c1 + c2) < 1) {
            x = -1;
            y = -1;
            moveHand(-1, -1, -1);
            return;
        }
        
        if (projYourTorso == null || projYourHand == null) {
            x = -1;
            y = -1;
            moveHand(-1, -1, -1);
            return;
        }
        
        openni.convertProjectiveToRealWorld(projYourTorso, yourTorso);
        openni.convertProjectiveToRealWorld(projYourHand, yourHand);
        
        int newX = (int)(((yourHand.x - yourTorso.x + 2000.0) / 4000.0) * width);
        int newY = (int)(((yourHand.y - yourTorso.y + 1000.0) / 2000.0) * height);
        int newZ = (int)(((yourTorso.z - yourHand.z) / 450.0) * 100.0);
        
        moveHand(newX, newY, newZ);
    }
    
    public int intersect(PImage hitTestImage) {
        if (!visible) return -1;
        
        int value = hitTestImage.pixels[(x / 10) + (y / 10) * (width / 10)] & 0xff;
        
        return value - 1;
    }
    
    public int intersectGreen(PImage hitTestImage) {
        if (!visible) return -1;
        
        int value = (hitTestImage.pixels[(x / 10) + (y / 10) * (width / 10)] >> 8) & 0xff;
        
        return value - 1;
    }
    
    public void grab(Target t, int secondaryIndex) {
        grabTarget = t;
        
        if (t != null)
            t.takeHoverDataFrom(this, secondaryIndex);
    }
    
    public void setTargetFrom(PImage hitTestImage, ArrayList<Target> targets) {
        if (grabTarget != null)
            grabTarget.setGrabbedBy(null); // Person will cover us later.
        
        int index = intersect(hitTestImage);
        int secondaryIndex = intersectGreen(hitTestImage);
        
        if (index == -1) grab(null, secondaryIndex);
        else grab(targets.get(index), secondaryIndex);
    }
    
    public Target getGrabTarget() {
        return grabTarget;
    }
    
    public boolean getIsVisible() {
      return visible;
    }
    
    public int getX() {
        return x;
    }
    
    public int getY() {
        return y;
    }
    
    public int getZ() {
        return z;
    }
}

class Person {
    Hand left, right;
    int userID;
    Target grabTarget;
    
    public Person(int id) {
        left = new Hand(this, true);
        right = new Hand(this, false);
        userID = id;
    }
    
    public int getID() {
        return userID;
    }
    
    public Hand getLeftHand() { return left; }
    public Hand getRightHand() { return right; }
    
    public void updateGrabbing(PImage hitTestImage, ArrayList<Target> targets) {
        left.setTargetFrom(hitTestImage, targets);
        right.setTargetFrom(hitTestImage, targets);
        
        if (left.getGrabTarget() == right.getGrabTarget() && (left.getGrabTarget() != null))
            left.getGrabTarget().setGrabbedBy(this);
    }
    
    public int getAverageX() {
        return (getLeftHand().getX() + getRightHand().getX()) / 2;
    }
    
    public int getAverageY() {
        return (getLeftHand().getY() + getRightHand().getY()) / 2;
    }
    
    public float getHandAngle() {
        return atan2(getRightHand().getY() - getLeftHand().getY(),
                     getRightHand().getX() - getLeftHand().getX());
    }
    
    public float getGrabRadius() {
        float dx = getRightHand().getY() - getLeftHand().getY(),
              dy = getRightHand().getX() - getLeftHand().getX();
        
        return (float)Math.sqrt(dx*dx + dy*dy);
    }
}

class Monitor {
    PVector topLeft, orientation;
    int width, height;
    
    public Monitor() {
        width = 490;
        height = 380;
        
        topLeft = new PVector(-490, -5, 2);
        orientation = new PVector(0, 0, 1);
    }
    
    String saveVector(PVector vec) {
        return vec.x + "," + vec.y + "," + vec.z;
    }
    
    PVector loadVector(String encoded) {
        String[] parts = encoded.split(",");
        if (parts.length != 3) return null;
        
        try {
            return new PVector(Float.parseFloat(parts[0]), Float.parseFloat(parts[1]), Float.parseFloat(parts[2]));
        } catch (NumberFormatException e) {
            return null;
        }
    }
    
    boolean loadCalibrationFrom(String encoded) {
        String[] parts = encoded.split(":");
        
        if (parts.length != 4) return false;
        PVector tmpTopLeft = loadVector(parts[0]);
        PVector tmpOrientation = loadVector(parts[1]);
        
        int tmpHeight;
        int tmpWidth;
        
        try {
            tmpWidth = Integer.parseInt(parts[2]);
            tmpHeight = Integer.parseInt(parts[3]);
        } catch (NumberFormatException e) {
            return false;
        }
        
        if (tmpTopLeft != null && tmpOrientation != null) {
            topLeft = tmpTopLeft;
            orientation = tmpOrientation;
            width = tmpWidth;
            height = tmpHeight;
            
            return true;
        } else {
            return false;
        }
    }
    
    void saveCalibration() {
        String outputPath = selectOutput();
        
        if (outputPath == null) return;
        
        Writer w = createWriter(outputPath);
        
        try {
            w.write(saveVector(topLeft) + ":" + saveVector(orientation) + ":" + width + ":" + height);
            w.close();
        } catch (IOException e) {
            System.err.println(e);
        }
    }
    
    void loadCalibration() {
        BufferedReader r = createReader("Calibration.txt");
        
        try {
            boolean success = loadCalibrationFrom(r.readLine());
            
            if (!success) {
                System.err.println("Unable to load file.");
            } else {
                System.err.println("Calibration data saved.");
            }
        } catch (IOException e) {
            System.err.println("I/O Error: " + e);
        }
    }
    
    void calibrate(PVector tl, PVector tr, PVector bl, PVector br) {
        PVector topOfFrame = PVector.sub(tl, tr);
        PVector bottomOfFrame = PVector.sub(bl, br);
        
        PVector leftOfFrame = PVector.sub(tl, bl);
        PVector rightOfFrame = PVector.sub(tr, br);
        
        System.err.println("--- CALIBRATION DATA ---");
        System.err.println("Top width:    " + topOfFrame.mag());
        System.err.println("Bottom width: " + topOfFrame.mag());
        System.err.println("-");
        System.err.println("Left height:    " + topOfFrame.mag());
        System.err.println("Right height: " + topOfFrame.mag());
    }
}

interface Target {
    void drawHitRegion(PGraphics g, int blueComponent);
    void draw();
    void setGrabbedBy(Person p);
    void moveTo(int x, int y);
    void rotateTo(float angleInRadians);
    void updateGrabbing();
    void takeHoverDataFrom(Hand h, int secondaryIndex);
}

interface SubTarget {
    void drawHitRegion(PGraphics g);
    void draw();
    void hoverOver();
    void updateHovering(boolean enabled);
}

class Rectangle implements Target {
    int x, y, w, h;
    float rotationAngle;
    Person grabbedBy;
    ArrayList<SubTarget> subTargets;
    
    public Rectangle() {
        w = 500;
        h = 300;
        x = (width - w) / 2;
        y = (height - h) / 2;
        rotationAngle = 0.0f;
        grabbedBy = null;
        subTargets = new ArrayList<SubTarget>();
    }
    
    boolean canBeMadeFullScreen() {  // meant to be overriden.
        return false;
    }
      
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
    
    void drawTargetHitRegions(PGraphics g, int blueComponent) { // meant to be overriden.
        g.fill(0, 0, blueComponent);
        g.rect(0, 0, w, h);
        
        for (int i = 0; i < subTargets.size(); i++) {
            g.fill(0, (i + 1), blueComponent);
            subTargets.get(i).drawHitRegion(g);
        }
    }
    
    void addSubTarget(SubTarget tar) {
        subTargets.add(tar);
    }
    
    void drawHitRegion(PGraphics g, int blueComponent) {
        if (fullScreenTarget != null) {
           if (fullScreenTarget == this) {
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
            g.pushMatrix();
            g.translate(x, y);
            g.translate(w / 2, h / 2);
            
            g.rotate(rotationAngle);
            
            if (grabbedBy != null) g.scale(1.5);
            
            g.translate(-w / 2, -h / 2);
            drawTargetHitRegions(g, blueComponent);
            
            g.popMatrix();
        }
    }
    
    void draw() {
        if (fullScreenTarget == this) {
            pushMatrix();
            translate(width / 2, height / 2);
            
            scale(Math.min(((float)width) / w, ((float)height) / h));
            
            translate(-w / 2, -h / 2);
            
            drawTarget();
            
            popMatrix();
            
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
            pushMatrix();
            translate(x + w / 2, y + h / 2);
            rotate(rotationAngle);
            translate(-w / 2, -h / 2);
            drawTarget();
            
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
        
        for (SubTarget tar : subTargets) {
            tar.updateHovering((grabbedBy == null && fullScreenTarget == null) || fullScreenTarget == this);
        }
    }
    
    void setGrabbedBy(Person p) {
        grabbedBy = p;
    }
    
    void takeHoverDataFrom(Hand p, int greenComponent) {
        if (greenComponent != -1) {
            SubTarget tar = subTargets.get(greenComponent);
            tar.hoverOver();
        }
    }
    
    void moveTo(int newX, int newY) {
        x = newX - w / 2;
        y = newY - h / 2;
    }
    
    void rotateTo(float angleInRadians) {
        rotationAngle = angleInRadians;
    }
    
    void updateGrabbing() {
        if (grabbedBy != null && fullScreenTarget == null) {
            moveTo(grabbedBy.getAverageX(), grabbedBy.getAverageY());
            rotateTo(grabbedBy.getHandAngle());
            
            if (grabbedBy.getGrabRadius() < 100) {
                fullScreenTarget = this; 
            }
            
        } else if (fullScreenTarget == this) {
            if (grabbedBy == null || grabbedBy.getGrabRadius() > 0.6 * width) {
                fullScreenTarget = null;
            }
        }
    }
}

class SceneViewTarget extends Rectangle {
    SceneViewTarget() {
        w = openni.sceneWidth() / 2;
        h = openni.sceneHeight() / 2;
        x = width - w;
        y = height - h;
    }
    
    boolean canBeMadeFullScreen() {
        return true;
    }
    
    void drawTarget() {
        /* draw mirror */
        pushMatrix();
        
        if (fullScreenTarget == this) {
            scale(0.5, 0.5);
        }
        
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
        
        popMatrix();
        
        if (fullScreenTarget == this) {
            pushMatrix();
            if (openni.irImage() != null)
                image(openni.irImage(), w / 2, 0, w / 2, h / 2);
            image(openni.depthImage(), 0, h / 2, w / w, h / 2);
            
            if (openni.rgbImage() != null)
                image(openni.rgbImage(), w / 2, h / 2, w / 2, h / 2);
            popMatrix();
        }
    }
}

class RefrigeratorMagnet extends Rectangle {
    String label;
    
    RefrigeratorMagnet(String s) {
        textFont(helvetica,90);
        
        w = (int)textWidth(s) + 20;
        h = 100;
        x = (int)random(width - w);
        y = (int)random(height - h);
        
        label = s;
    }
    
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

class KeyboardTarget extends Rectangle {
   String topRow = "JFDWK@",
       secondRow = "GNIRM<", 
        thirdRow = "LTEOU ",
        forthRow = "YSAHV ",
        fifthRow = "XPCBQZ";
   
   String letters;
   
   KeyboardTarget() {
       x = y = 0;
       w = 600;
       h = 600;
       letters = "";
       
       String[] rows = { topRow, secondRow, thirdRow, forthRow, fifthRow };
        
       for (int i = 0; i < 6; i += 1) {
           for (int j = 0; j < 5; j += 1) {
               if (rows[j].charAt(i) != ' ')
                   addSubTarget(new ExplodingButton(i * 100, j * 100 + 100, 90, 90, rows[j].substring(i, i + 1), this));
           }
       }
   }
   
   void drawTarget() {
       if (grabbedBy != null)
            stroke(200, 0, 0);
        else
            stroke(200, 200, 0);
        
        strokeWeight(5);
        fill(10, 0, 0);
        
        rect(0, 0, w, h);
        
        for (SubTarget target : subTargets) {
            target.draw();
        }
       
       fill(255);
       textFont(helvetica, 90);
       text(letters, 10, 80);
   }
   
   void typeLetter(String letter) {
       if (letter.equals("@")) {
           targetsToAddNextCycle.add(new RefrigeratorMagnet(letters));
           
           letters = "";
       } else if (letter.equals("<")) {
           letters = letters.substring(0, letters.length() - 1);
       } else {
           letters += letter;
       }
   }
}

class ExplodingButton implements SubTarget {
    int x, y, w, h;
    float powerLevel;
    boolean hoveredOver;
    String letter;
    KeyboardTarget parent;
    
    ExplodingButton(int newX, int newY, int newW, int newH, String newLetter, KeyboardTarget t) {
        x = newX;
        y = newY;
        w = newW;
        h = newH;
        powerLevel = 0.0;
        hoveredOver = false;
        letter = newLetter;
        parent = t;
    }
    
    void drawHitRegion(PGraphics g) {
        g.noStroke();
        g.rect(x, y, w, h);
    }
    
    void draw() {
        fill((powerLevel   / 100.0 * 0.9 + 0.1) * 255.0, 0, 0, 100);
        stroke((powerLevel / 100.0 * 0.9 + 0.1) * 255.0, 0, 0, 150);
        strokeWeight(10);
        rect(x, y, w, h);
        
        fill(255);
        textFont(helvetica, h * 0.8);
        text(letter, x + (w - textWidth(letter)) / 2, y + h * 0.8);
    }
    
    void hoverOver() {
        hoveredOver = true;
    }
    
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
    
    float getPowerLevel() {
        return powerLevel;
    }
}

void setup() {
    size(1920, 1080);
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

void onNewUser(int userID) {
    System.out.println("New User: " + userID + "; start pose detection!");
    
    openni.startPoseDetection("Psi", userID);
    
    people.add(new Person(userID));
}

void onLostUser(int userID) {
    System.out.println("Lost User: " + userID);
    
    int foundIndex = -1;
    
    for (int i = 0; i < people.size(); i++) {
        if (people.get(i).getID() == userID) {
            foundIndex = i;
            break;
        }
    }
    
    people.remove(foundIndex);
}

void onStartSession(PVector vec) {
    System.out.println("Start session / Vector: " + vec);
}

void onEndSession() {
    System.out.println("End session!");
}

void onFocusSession(String stuff, PVector vec, float stuff2) {
    System.out.println("Session focused; " + stuff + " vec=" + vec + ", stuff2=" + stuff2);
}

void onEndCalibration(int userID, boolean successful) {
    System.out.println("Calibrated User ID : " + userID + " successful : " + successful);
    
    if (successful) {
        openni.startTrackingSkeleton(userID);
    } else {
        openni.startPoseDetection("Psi", userID);
    }
}

void onStartPose(String pose, int userID) {
    println("onStartPose - userID: " + userID + "; pose = " + pose);

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