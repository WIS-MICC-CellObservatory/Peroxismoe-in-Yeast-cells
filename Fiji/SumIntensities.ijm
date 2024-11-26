//segment the yeast cells and the Peroxisome organelles in it
//Count the total intensity of the ECI-1 protein signal inside and outside the organelles
//output: 
//1. Mean and total intensity of ECI-1 signal (of pixels above threshold) inside and outside the organelles

#@ File (label="Yeast image path",value="A:\\liorpe\\Eci1 article\\Raw data\\Fig 1\\Panel A\\Image2_w1Brightfield_s62.tif", persist=true, description="make sure it is in sync with peroxisome and protein paths") iYeastFilePath
#@ File (label="Peroxisome image path",value="A:\\liorpe\\Eci1 article\\Raw data\\Fig 1\\Panel A\\Image2_w3confmCherry_s62.tif", persist=true, description="make sure it is in sync with yeast and protein paths") iPeroxisomeFilePath
#@ File (label="Protein image path",value="A:\\liorpe\\Eci1 article\\Raw data\\Fig 1\\Panel A\\Image2_w2confGFP_s62.tif", persist=true, description="make sure it is in sync with yeast and peroxisome paths") iProteinFilePath
#@ File (label = "Output directory", style = "directory", persist=true) iOutputDir

#@ Integer(label="Peroxisome mean intensity threshold",value="200", persist=true) iPeroxisomeMeanIntensityThreshold
#@ Integer(label="Protein intensity threshold",value="400", persist=true) iProteinIntensityThreshold
#@ Integer(label="Yeast cell diameter (pixels)",value="40", persist=true) iDiameter
// Boolean(label="Dilate peroxisome",value="True", persist=true) iDilatePeroxisome
#@ File(label="Cellpose, Enviorenment",value="C:\\ProgramData\\anaconda3\\envs\\cellpose", style="directory", persist=true, description="Cellpose env.") iCellposeEnv
var gRowIndex = 0;


//CONSTANTS
var TABLE_NAME = "Intensities";
var YEAST_ROI_LABEL = "Yeast";
var PEROXISOME_ROI_LABEL = "Peroxisome";
var SUM_INTENSITIES_COLUMN = "Sum ECI-1 Intensities";
var NUM_POINTS_COLUMN = "Num ECI-1 pixels above threshold";
var AVG_INTENSITY_COLUMN = "Avg. ECI-1 intensity";
var TOTAL_POINTS = "Total Pixels";
var YEAST_COLOR = "Red";
var PEROXISOME_COLOR = "Green";


processFile();
waitForUser("-----------------------DONE-------------------");
function processFile() {
	close("*");
	close("Results");
	roiManager("reset");
	Table.create(TABLE_NAME);
	
	if(!OpenImage(iYeastFilePath)){
		return;
	}
	yeastImageId = getImageID();
	if(!OpenImage(iPeroxisomeFilePath)){
		return;
	}
	peroxisomeImageId = getImageID();	
	if(!OpenImage(iProteinFilePath)){
		return;
	}
	proteinImageId= getImageID();	
	
	//segment Peroxisome organelles using stardist - do that first as it assumes roi mangere is empty
	RunStardistModel_LSCF(peroxisomeImageId, "Versatile (fluorescent nuclei)", "ROI Manager", "true",  "");
	//filter low intensity rois
	n = FilterRois_LSCF(peroxisomeImageId, iPeroxisomeMeanIntensityThreshold, -1, "Mean");
	//unite all Peroxisome rois to a single one
	UniteRois_LSCF(PEROXISOME_ROI_LABEL);
	
	// segment Yeast using cellpose
	yeastLabelImageId = RunCellpose_LSCF(yeastImageId, "Cyto3", iDiameter, 1,0,"--use_gpu",iCellposeEnv);
	//create single roi (roi 0)
	LabelImageToSingleROI_LSCF(yeastLabelImageId,YEAST_ROI_LABEL);
	
	//consider only the Peroxisome organelles residing in a yeast cell
	ContainedRoi(peroxisomeImageId,1,0,PEROXISOME_ROI_LABEL);
	
	//remove peroxisome roi (to be left with two rois - one for the yeast and one for the contained proxisomes
	roiManager("select", 0);
	roiManager("delete");
	
	//count all the protein intensities above threshold in the entire yeast
	CountIntensities(proteinImageId, iProteinIntensityThreshold, 0);
	//count all the protein intensities above threshold in the Peroxisome organelles
	CountIntensities(proteinImageId, iProteinIntensityThreshold, 1);
	
	//calc the avg protein intensity of pixels in yeast outside the proxisome
	CalcExtAvg();
	
	//calc the relative areas of peroxisome and yeast and relative protein sum_intensities of peroxisome and yeast
	CalcRelativeMeasurments();
	
	outputDir = iOutputDir + File.separator + File.getNameWithoutExtension(iYeastFilePath);
	File.makeDirectory(outputDir);
	r = round(random*1000); //add random number to table file name, to enable multiple opens in excel
	Table.save(outputDir + File.separator + TABLE_NAME + r + ".csv", TABLE_NAME);
	roiManager("select", 0);
	roiManager("Set Color", YEAST_COLOR);
	roiManager("select", 1);
	roiManager("Set Color", PEROXISOME_COLOR);
	roiManager("save", outputDir + File.separator + "RoiSet.zip");
}


//input: none
//output: none
//Replaces all rois with a single one 
function UniteRois_LSCF(roiLabel){
	n = roiManager("count");
	if(n <= 1){
		return;
	}
	indexes = Array.getSequence(n);
	roiManager("select", indexes);
	roiManager("combine");
	roiManager("reset");
	roiManager("add");
	roiManager("select", 0);
	roiManager("rename", roiLabel);
}

//Input:imageId,  min_value, max_value, property
//Outpu: number of deleted rois
//Goes over rois and removes all those not between min and max value (< 0 to ignore min/max)
function FilterRois_LSCF(imageId, lowValue, highValue, property){
	roiManager("deselect");
	selectImage(imageId);
	roiManager("measure");
	values = Table.getColumn(property,"Results");
	n = roiManager("count");
	for(i=n-1;i>=0;i--){
		if((lowValue >= 0 && values[i] < lowValue) || (highValue >= 0 && values[i] > highValue)){
			roiManager("select", i);
			roiManager("delete");		
		}
	}
	return n -  roiManager("count");
}

function CalcRelativeMeasurments(){
	totalYeastNumPoints = Table.get(YEAST_ROI_LABEL + ": "+TOTAL_POINTS, gRowIndex, TABLE_NAME);
	totalPeroxisomeNumPoints = Table.get(PEROXISOME_ROI_LABEL + ": "+TOTAL_POINTS, gRowIndex, TABLE_NAME);
	Table.set("Peroxisome area ratio", gRowIndex,totalPeroxisomeNumPoints/totalYeastNumPoints , TABLE_NAME);	

	totalYeastSumIntensities = Table.get(YEAST_ROI_LABEL + ": "+SUM_INTENSITIES_COLUMN, gRowIndex, TABLE_NAME);
	totalPeroxisomeSumIntensities = Table.get(PEROXISOME_ROI_LABEL + ": "+SUM_INTENSITIES_COLUMN, gRowIndex, TABLE_NAME);
	Table.set("Peroxisome sum intensities ratio", gRowIndex,totalPeroxisomeSumIntensities/totalYeastSumIntensities , TABLE_NAME);	

}
function CalcExtAvg(){
	totalYeastProteinNumPoints = Table.get(YEAST_ROI_LABEL + ": "+NUM_POINTS_COLUMN, gRowIndex, TABLE_NAME);
	totalYeastAvgIntensities = Table.get(YEAST_ROI_LABEL + ": "+AVG_INTENSITY_COLUMN, gRowIndex, TABLE_NAME);
	
	totalPeroxisomeProteinNumPoints = Table.get(PEROXISOME_ROI_LABEL + ": "+NUM_POINTS_COLUMN, gRowIndex, TABLE_NAME);
	totalPeroxisomeAvgIntensities = Table.get(PEROXISOME_ROI_LABEL + ": "+AVG_INTENSITY_COLUMN, gRowIndex, TABLE_NAME);
	
	Table.set("Avg. ECI-1 intensities in yeast outside peroxisome", gRowIndex, ((totalYeastAvgIntensities*totalYeastProteinNumPoints - totalPeroxisomeAvgIntensities*totalPeroxisomeProteinNumPoints)/(totalYeastProteinNumPoints-totalPeroxisomeProteinNumPoints)), TABLE_NAME);
}
function RunStardistModel_LSCF(imageId, model/*Versatile (fluorescent nuclei)/...*/, outputType/*ROI Manager/Label Image/Both*/, normalizeInput/*"true"*/,  additional_flags/*""*/){
	selectImage(imageId);
	title = getTitle();
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'"+title+"', 'modelChoice':'"+model+"', 'normalizeInput':'"+normalizeInput+ "', 'outputType':'"+outputType+"'"+ additional_flags+"], process=[false]");
	return getImageID();
}

function RunCellpose_LSCF(imageId, model, diameter, ch1, ch2, additional_flags, cellposeEnv){
	selectImage(imageId);
	modelAndPath = " model="+model+" model_path=path\\to\\own_cellpose_model";
	if(File.exists(model)){
		modelAndPath = "model= model_path=["+model+"]";
	}
	run("Cellpose ...", "env_path=["+cellposeEnv+"] env_type=conda" + modelAndPath + " diameter="+diameter + " ch1="+ch1 + " ch2="+ch2 + " additional_flags="+additional_flags);
	return getImageID();
}

//input: label image id
//Output: mask image id
//Creates a mask from a label image
function LabelImageToMask_LSCF(labelImageId){
	setThreshold(1, 100000000, "raw");	
	selectImage(labelImageId);
	run("Convert to Mask");
	return getImageID();
}
//input: mask image id
//Output: none
//Creates a single roi from mask
function MaskToRoi_LSCF(maskImageId, roiLabel){
	run ("Create Selection");           
	roiManager("Add");
	RenameLastRoi_LSCF(roiLabel);
}
//input: roi label
//Output: none
//Renames the last roi to the given label
function RenameLastRoi_LSCF(roiLabel){
	n = roiManager("count");
	roiManager("deselect");
	roiManager("select", n-1);
	roiManager("rename", roiLabel);
}
function LabelImageToSingleROI_LSCF(labelImageId, roiLabel){
	maskImageId = LabelImageToMask_LSCF(labelImageId);
	MaskToRoi_LSCF(maskImageId, roiLabel);
	selectImage(maskImageId);
//	close();
//	selectImage(labelImageId);
}

function CountIntensities(imageId, threshold, roiInd){
	sum = 0;
	numPoints = 0;
	//eci1ImageId = ExtractChannel_LSCF(imageId,channel);
	selectImage(imageId);
	roiManager("deselect");
	roiManager("Select",roiInd);
	roiName = Roi.getName;
	Roi.getContainedPoints(xpoints, ypoints);
	for(i=0;i<xpoints.length;i++){
		v = getPixel(xpoints[i], ypoints[i]);
		if(v > threshold){
			sum += v;
			numPoints += 1;
		}
	}
	Table.set(roiName+": " + SUM_INTENSITIES_COLUMN, gRowIndex, sum, TABLE_NAME);
	Table.set(roiName+": " + NUM_POINTS_COLUMN, gRowIndex, numPoints, TABLE_NAME);
	Table.set(roiName+": " + AVG_INTENSITY_COLUMN, gRowIndex, sum/numPoints, TABLE_NAME);
	Table.set(roiName+": " + TOTAL_POINTS, gRowIndex, xpoints.length, TABLE_NAME);
}

//Input: imageId
//Output: ImageId of mask image
function RoiToMask(imageId,roiInd){
	roiManager("deselect");
	roiManager("select",roiInd);
	selectImage(imageId);
	run("Remove Overlay");
	run("Create Mask");
	waitForUser("check image: "+roiInd);
	maskImageId = getImageID();
	selectImage(imageId);
	run("Remove Overlay");
	selectImage(maskImageId);
	return maskImageId;
}

// create mask from the contained roi then clear outside using the container roi
function ContainedRoi(imageId, containerRoiInd,containedRoiInd, roiLabel){
	selectImage(imageId);
	roiManager("deselect");
	roiManager("select", newArray(containerRoiInd,containedRoiInd));
	roiManager("and");
	roiManager("add");
	RenameLastRoi_LSCF(roiLabel);
}
function OpenImage(full_path){
	run("Bio-Formats Importer", "open=["+full_path+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	gImageImageId = getImageID();
	return true;
}

function ExtractSlice_LSCF(ImageId,slice){
	return ExtractChannelAndSlice_LSCF(ImageId,1,slice);
}

function ExtractChannel_LSCF(ImageId,channel){
	return ExtractChannelAndSlice_LSCF(ImageId,channel,1);
}
function ExtractChannelAndSlice_LSCF(ImageId,channel,slice){
	selectImage(ImageId);
	run("Make Substack...", "channels="+channel+" slices="+slice);
	sliceImageId = getImageID();
	return sliceImageId;
}
