import gab.opencv.*;

import java.awt.Rectangle;
import controlP5.*;

OpenCV opencv;
OpenCV opencv1;
boolean save=false;
float scale=0.3;

PImage src, preProcessedImage, processedImage, contoursImage, b;

ArrayList<Contour> contours;

// List of detected contours parsed as blobs (every frame)
ArrayList<Contour> newBlobContours;

// List of my blob objects (persistent)
ArrayList<Blob> blobList;
PImage img;

// Number of blobs detected over all time. Used to set IDs.
int blobCount = 0;

float contrast = 0.54;
int brightness = 0;
int threshold = 136;
boolean useAdaptiveThreshold = false; // use basic thresholding
int thresholdBlockSize = 489;
int thresholdConstant = 45;
int blobSizeThreshold = 0;
int blobSizemax = 20;

int blurSize = 3;
double minX=1000;
double minY=1000;
// Control vars
ControlP5 cp5;
int buttonColor;
int buttonBgColor;

void setup() {
  frameRate(15);
  
  
  opencv = new OpenCV(this, 900, 900);
  contours = new ArrayList<Contour>();
  img=loadImage("900_2samples/Ricoh9h37_6_11.png");
  opencv.loadImage("900_2samples/Ricoh9h37_6_11.png");
  
   b = opencv.getSnapshot(opencv.getB());  
   src=b;
  opencv.loadImage(b);

  // Blobs list
  blobList = new ArrayList<Blob>();
  
  size(int(opencv.width*scale*2 + 200), int(opencv.height*scale*2), P2D);
  
  // Init Controls
  cp5 = new ControlP5(this);
  initControls();
  
  // Set thresholding
  toggleAdaptiveThreshold(useAdaptiveThreshold);
}

void draw() {
  
  
  
  
  //////////
  ///////////////////////////////
  // <1> PRE-PROCESS IMAGE
  // - Grey channel 
  // - Brightness / Contrast
  ///////////////////////////////
  
  // Gray channel
  opencv.gray();
  
  //opencv.brightness(brightness);
  opencv.contrast(contrast);
  
  // Save snapshot for display
  preProcessedImage = opencv.getSnapshot();
  
  ///////////////////////////////
  // <2> PROCESS IMAGE
  // - Threshold
  // - Noise Supression
  ///////////////////////////////
  
  // Adaptive threshold - Good when non-uniform illumination
  if (useAdaptiveThreshold) {
    
    // Block size must be odd and greater than 3
    if (thresholdBlockSize%2 == 0) thresholdBlockSize++;
    if (thresholdBlockSize < 3) thresholdBlockSize = 3;
    
    opencv.adaptiveThreshold(thresholdBlockSize, thresholdConstant);
    
  // Basic threshold - range [0, 255]
  } else {
    opencv.threshold(threshold);
  }

  // Invert (black bg, white blobs)
  opencv.invert();
  
  // Reduce noise - Dilate and erode to close holes
  opencv.dilate();
  opencv.erode();
  
  // Blur
  opencv.blur(blurSize);
  
  // Save snapshot for display
  processedImage = opencv.getSnapshot();
  
  ///////////////////////////////
  // <3> FIND CONTOURS  
  ///////////////////////////////
  
  detectBlobs();
  // Passing 'true' sorts them by descending area.
  //contours = opencv.findContours(true, true);
  
  // Save snapshot for display
  contoursImage = opencv.getSnapshot();
  
  // Draw
  pushMatrix();
    
    // Leave space for ControlP5 sliders
    translate(width-src.width*scale*2, 0);
    
    // Display images
    displayImages();
    
    // Display contours in the lower right window
    pushMatrix();
      scale(scale);
      translate(src.width, src.height);
      
      // Contours
      //displayContours();
      //displayContoursBoundingBoxes();
      
      // Blobs
      displayBlobs();
      
    popMatrix(); 
    
  popMatrix();
}

///////////////////////
// Display Functions
///////////////////////

void displayImages() {
  
  pushMatrix();
  scale(scale);
  image(src, 0, 0);
  image(preProcessedImage, src.width, 0);
  image(processedImage, 0, src.height);
  image(src, src.width, src.height);
  popMatrix();
  
  stroke(255);
  fill(255);
  textSize(12);
  text("Source", 10, 25); 
  text("Pre-processed Image", src.width/2 + 10, 25); 
  text("Processed Image", 10, src.height/2 + 25); 
  text("Tracked Points", src.width/2 + 10, src.height/2 + 25);
}

void displayBlobs() {
 
  
 /* for (Blob b : blobList) {
   if(b.getY()<minY){
     minY=b.getY();
     minX=b.getX();}
   if(b.getY()==minY){
     if(b.getX()<minX){
      minX=b.getX();}}
    
    
  }*/
  
  for (Blob b : blobList) {
    strokeWeight(1);
    b.display();
    if(save==true){
    print( "x "+ ((b.getX()-minX)/41.18));
    println( " y "+ ((b.getY()-minY)/41.18));}
  }
}



void detectBlobs() {
  
  // Contours detected in this frame
  // Passing 'true' sorts them by descending area.
  contours = opencv.findContours(true, true);
  
  newBlobContours = getBlobsFromContours(contours);
  
  //println(contours.length);
  
  // Check if the detected blobs already exist are new or some has disappeared. 
  
  // SCENARIO 1 
  // blobList is empty
  if (blobList.isEmpty()) {
    // Just make a Blob object for every face Rectangle
    for (int i = 0; i < newBlobContours.size(); i++) {
      println("+++ New blob detected with ID: " + blobCount);
      blobList.add(new Blob(this, blobCount, newBlobContours.get(i)));
      blobCount++;
    }
  
  // SCENARIO 2 
  // We have fewer Blob objects than face Rectangles found from OpenCV in this frame
  } else if (blobList.size() <= newBlobContours.size()) {
    boolean[] used = new boolean[newBlobContours.size()];
    // Match existing Blob objects with a Rectangle
    for (Blob b : blobList) {
       // Find the new blob newBlobContours.get(index) that is closest to blob b
       // set used[index] to true so that it can't be used twice
       float record = 50000;
       int index = -1;
       for (int i = 0; i < newBlobContours.size(); i++) {
         float d = dist(newBlobContours.get(i).getBoundingBox().x, newBlobContours.get(i).getBoundingBox().y, b.getBoundingBox().x, b.getBoundingBox().y);
         //float d = dist(blobs[i].x, blobs[i].y, b.r.x, b.r.y);
         if (d < record && !used[i]) {
           record = d;
           index = i;
         } 
       }
       // Update Blob object location
       used[index] = true;
       b.update(newBlobContours.get(index));
    }
    // Add any unused blobs
    for (int i = 0; i < newBlobContours.size(); i++) {
      if (!used[i]) {
        println("+++ New blob detected with ID: " + blobCount);
        blobList.add(new Blob(this, blobCount, newBlobContours.get(i)));
        //blobList.add(new Blob(blobCount, blobs[i].x, blobs[i].y, blobs[i].width, blobs[i].height));
        blobCount++;
      }
    }
  
  // SCENARIO 3 
  // We have more Blob objects than blob Rectangles found from OpenCV in this frame
  } else {
    // All Blob objects start out as available
    for (Blob b : blobList) {
      b.available = true;
    } 
    // Match Rectangle with a Blob object
    for (int i = 0; i < newBlobContours.size(); i++) {
      // Find blob object closest to the newBlobContours.get(i) Contour
      // set available to false
       float record = 50000;
       int index = -1;
       for (int j = 0; j < blobList.size(); j++) {
         Blob b = blobList.get(j);
         float d = dist(newBlobContours.get(i).getBoundingBox().x, newBlobContours.get(i).getBoundingBox().y, b.getBoundingBox().x, b.getBoundingBox().y);
         //float d = dist(blobs[i].x, blobs[i].y, b.r.x, b.r.y);
         if (d < record && b.available) {
           record = d;
           index = j;
         } 
       }
       // Update Blob object location
       Blob b = blobList.get(index);
       b.available = false;
       b.update(newBlobContours.get(i));
    } 
    // Start to kill any left over Blob objects
    for (Blob b : blobList) {
      if (b.available) {
        b.countDown();
        if (b.dead()) {
          b.delete = true;
        } 
      }
    } 
  }
  
  // Delete any blob that should be deleted
  for (int i = blobList.size()-1; i >= 0; i--) {
    Blob b = blobList.get(i);
    if (b.delete) {
      blobList.remove(i);
    } 
  }
  
  
  
  
  
}

ArrayList<Contour> getBlobsFromContours(ArrayList<Contour> newContours) {
  
  ArrayList<Contour> newBlobs = new ArrayList<Contour>();
  
  // Which of these contours are blobs?
  for (int i=0; i<newContours.size(); i++) {
    
    Contour contour = newContours.get(i);
    Rectangle r = contour.getBoundingBox();
    
    if (//(contour.area() > 0.9 * src.width * src.height) ||
        (r.width < blobSizeThreshold || r.height < blobSizeThreshold) || (r.width > blobSizemax || r.height > blobSizemax))
      continue;
    
    newBlobs.add(contour);
  }
  
  return newBlobs;
}

//////////////////////////
// CONTROL P5 Functions
//////////////////////////

void initControls() {
  // Slider for contrast
  cp5.addSlider("contrast")
     .setLabel("contrast")
     .setPosition(20,50)
     .setRange(0.0,6.0)
     ;
     
  // Slider for threshold
  cp5.addSlider("threshold")
     .setLabel("threshold")
     .setPosition(20,110)
     .setRange(0,255)
     ;
  
  // Toggle to activae adaptive threshold
  cp5.addToggle("toggleAdaptiveThreshold")
     .setLabel("use adaptive threshold")
     .setSize(10,10)
     .setPosition(20,144)
     ;
     
  // Slider for adaptive threshold block size
  cp5.addSlider("thresholdBlockSize")
     .setLabel("a.t. block size")
     .setPosition(20,180)
     .setRange(1,700)
     ;
     
  // Slider for adaptive threshold constant
  cp5.addSlider("thresholdConstant")
     .setLabel("a.t. constant")
     .setPosition(20,200)
     .setRange(-100,100)
     ;
  
  // Slider for blur size
  cp5.addSlider("blurSize")
     .setLabel("blur size")
     .setPosition(20,260)
     .setRange(1,20)
     ;
     
  // Slider for minimum blob size
  cp5.addSlider("blobSizeThreshold")
     .setLabel("min blob size")
     .setPosition(20,290)
     .setRange(0,60)
     ;
     
  cp5.addSlider("blobSizemax")
     .setLabel("max blob size")
     .setPosition(20,320)
     .setRange(0,60)
     ;
     
  // Store the default background color, we gonna need it later
  buttonColor = cp5.getController("contrast").getColor().getForeground();
  buttonBgColor = cp5.getController("contrast").getColor().getBackground();
}

void toggleAdaptiveThreshold(boolean theFlag) {
  
  useAdaptiveThreshold = theFlag;
  
  if (useAdaptiveThreshold) {
    
    // Lock basic threshold
    setLock(cp5.getController("threshold"), true);
       
    // Unlock adaptive threshold
    setLock(cp5.getController("thresholdBlockSize"), false);
    setLock(cp5.getController("thresholdConstant"), false);
       
  } else {
    
    // Unlock basic threshold
    setLock(cp5.getController("threshold"), false);
       
    // Lock adaptive threshold
    setLock(cp5.getController("thresholdBlockSize"), true);
    setLock(cp5.getController("thresholdConstant"), true);
  }
}

void setLock(Controller theController, boolean theValue) {
  
  theController.setLock(theValue);
  
  if (theValue) {
    theController.setColorBackground(color(150,150));
    theController.setColorForeground(color(100,100));
  
  } else {
    theController.setColorBackground(color(buttonBgColor));
    theController.setColorForeground(color(buttonColor));
  }
}

