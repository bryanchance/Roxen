#!/usr/local/bin/pike
#define max(i, j) (((i)>(j)) ? (i) : (j))
#define min(i, j) (((i)<(j)) ? (i) : (j))
#define abs(arg) ((arg)*(1-2*((arg)<0)))

#define PI 3.14159265358979
//inherit Stdio;

import Image;
import Array;
import Stdio;
inherit "polyline.pike";
constant LITET = 1.0e-40;
constant STORT = 1.0e40;

//inherit "../testserver/roxen/server/base_server/roxenlib.pike"; 

//Denna funktion ritar text-bilderna, initierar max, fixar till bk-bilder
//och allt annat som �r gemensamt f�r alla sorters diagram.
//Denna funktion anropas i create_XXX.


void draw(object(image) img, float h, array(float) coords)
{
  for(int i=0; i<sizeof(coords)-3; i+=2)
    {
      img->
	polygone(make_polygon_from_line(h, coords[i..i+3],
					1, 1)[0]);
    }
}


mapping(string:mixed) init(mapping(string:mixed) diagram_data)
{
  float xminvalue=0.0, xmaxvalue=-STORT, yminvalue=0.0, ymaxvalue=-STORT;

  foreach(diagram_data["datapoints"], array(float) d)
    {
      int j=sizeof(d);

      for(int i; i<j; i++)
	{
	  float k;
	  if (xminvalue>(k=d[i]))
	    xminvalue=k;
	  if (xmaxvalue<(k=d[i]))
	    xmaxvalue=k;
	  
	  if (yminvalue>(k=d[++i]))
	    yminvalue=k;
	  if (ymaxvalue<(k=d[i]))
	    ymaxvalue=k;
	}
    }
  xmaxvalue=max(xmaxvalue, xminvalue+LITET);
  ymaxvalue=max(ymaxvalue, yminvalue+LITET);

  write("ymaxvalue:"+ymaxvalue+"\n");
  write("yminvalue:"+yminvalue+"\n");
  write("xmaxvalue:"+xmaxvalue+"\n");
  write("xminvalue:"+xminvalue+"\n");

  if ((!(diagram_data["xminvalue"])) ||
      (diagram_data["xminvalue"]>xminvalue))
    diagram_data["xminvalue"]=xminvalue;
  if ((!(diagram_data["xmaxvalue"])) ||
      (diagram_data["xmaxvalue"]<xmaxvalue))
    if (xmaxvalue<0.0)
      diagram_data["xmaxvalue"]=0.0;
    else
      diagram_data["xmaxvalue"]=xmaxvalue;
  if ((!(diagram_data["yminvalue"])) ||
      (diagram_data["yminvalue"]>yminvalue))
    diagram_data["yminvalue"]=yminvalue;
  if ((!(diagram_data["ymaxvalue"])) ||
      (diagram_data["ymaxvalue"]<ymaxvalue))
    if (ymaxvalue<0.0)
      diagram_data["ymaxvalue"]=0.0;
    else
      diagram_data["ymaxvalue"]=ymaxvalue;


  return diagram_data;

};

object get_font(string j, int p, int t, int h, string fdg, int s, int hd)
{
  return Image.font()->load("avant_garde");
};


//rita bilderna f�r texten
//ta ut xmaxynames, ymaxynames xmaxxnames ymaxxnames
mapping(string:mixed) create_text(mapping(string:mixed) diagram_data)
{
  object notext=get_font("avant_garde", 32, 0, 0, "left",0,0);
  int j;
  diagram_data["xnamesimg"]=allocate(j=sizeof(diagram_data["xnames"]));
  for(int i=0; i<j; i++)
    if ((diagram_data["values_for_xnames"][i]>LITET)||(diagram_data["values_for_xnames"][i]<-LITET))
      diagram_data["xnamesimg"][i]=notext->write(diagram_data["xnames"][i])->scale(0,diagram_data["fontsize"]);
    else
      diagram_data["xnamesimg"][i]=
	image(diagram_data["fontsize"],diagram_data["fontsize"]);

  diagram_data["ynamesimg"]=allocate(j=sizeof(diagram_data["ynames"]));
  for(int i=0; i<j; i++)
    if ((diagram_data["values_for_ynames"][i]>LITET)||(diagram_data["values_for_ynames"][i]<-LITET))
      diagram_data["ynamesimg"][i]=notext->write(diagram_data["ynames"][i])->scale(0,diagram_data["fontsize"]);
    else
      diagram_data["ynamesimg"][i]=
	image(diagram_data["fontsize"],diagram_data["fontsize"]);



  if (diagram_data["orient"]=="vert")
    for(int i; i<sizeof(diagram_data["xnamesimg"]); i++)
      {
      diagram_data["xnamesimg"][i]=diagram_data["xnamesimg"][i]->rotate_ccw();
      }
  int xmaxynames=0, ymaxynames=0, xmaxxnames=0, ymaxxnames=0;
  
  foreach(diagram_data["xnamesimg"], object img)
    {
      if (img->ysize()>ymaxxnames) 
	ymaxxnames=img->ysize();
    }
  foreach(diagram_data["xnamesimg"], object img)
    {
      if (img->xsize()>xmaxxnames) 
	xmaxxnames=img->xsize();
    }
  foreach(diagram_data["ynamesimg"], object img)
    {
      if (img->ysize()>ymaxynames) 
	ymaxynames=img->ysize();
    }
  foreach(diagram_data["ynamesimg"], object img)
    {
      if (img->xsize()>xmaxynames) 
	xmaxynames=img->xsize();
    }
  
  diagram_data["ymaxxnames"]=ymaxxnames;
  diagram_data["xmaxxnames"]=xmaxxnames;
  diagram_data["ymaxynames"]=ymaxynames;
  diagram_data["xmaxynames"]=xmaxynames;


}

//Denna funktion returnerar en mapping med 
// (["graph":image-object, "xstart": var_i_bilden_vi_kan_b�rja_rita_data-int,
//   "ystart": var_i_bilden_vi_kan_b�rja_rita_data-int,
//   "xstop":int, "ystop":int 
//    osv...]);

/*
 foreach(make_polygon_from_line(...), array(float) p)
    img->polygone(p);
*/

string no_end_zeros(string f)
{
  if (search(f, ".")!=-1)
    {
      int j;
      for(j=sizeof(f)-1; f[j]=='0'; j--)
	{}
      if (f[j]=='.')
	return f[..--j];
      else
	return f[..j];
    }
  return f;
}

mapping(string:mixed) create_graph(mapping diagram_data)
{
  //Supportar bara xsize>=100
  int si=diagram_data["fontsize"];

  string where_is_ax;

  object(image) graph;
  if (diagram_data["bgcolor"])
    graph=image(diagram_data["xsize"],diagram_data["ysize"],
		@(diagram_data["bgcolor"]));
  else
    graph=diagram_data["image"];

  //Best�m var vi ska rita ut x och y-axeln:
  init(diagram_data);
  //Ta reda hur m�nga och hur stora textmassor vi ska skriva ut
  if (!(diagram_data["xspace"]))
    {
      //Initera hur l�ngt det ska vara emellan.
      
      float range=(diagram_data["xmaxvalue"]-
		 diagram_data["xminvalue"]);
      write("range"+range+"\n");
      float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
      if (range/space>5.0)
	{
	  if(range/(2.0*space)>5.0)
	    {
	      space=space*5.0;
	    }
	  else
	    space=space*2.0;
	}
      diagram_data["xspace"]=space;      
    }
  if (!(diagram_data["yspace"]))
    {
      //Initera hur l�ngt det ska vara emellan.
      
      float range=(diagram_data["ymaxvalue"]-
		 diagram_data["yminvalue"]);
      float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
      if (range/space>5.0)
	{
	  if(range/(2.0*space)>5.0)
	    {
	      space=space*5.0;
	    }
	  else
	    space=space*2.0;
	}
      diagram_data["yspace"]=space;      
    }
 


  if (!(diagram_data["values_for_xnames"]))
    {
      float start;
      start=diagram_data["xminvalue"];
      start=diagram_data["xspace"]*ceil((start)/diagram_data["xspace"]);
      diagram_data["values_for_xnames"]=({start});
      while(diagram_data["values_for_xnames"][-1]<=
	    diagram_data["xmaxvalue"]-diagram_data["xspace"])
	diagram_data["values_for_xnames"]+=({start+=diagram_data["xspace"]});
    }
  if (!(diagram_data["values_for_ynames"]))
    {
      float start;
      start=diagram_data["yminvalue"];
      start=diagram_data["yspace"]*ceil((start)/diagram_data["yspace"]);
      diagram_data["values_for_ynames"]=({start});
      while(diagram_data["values_for_ynames"][-1]<=
	    diagram_data["ymaxvalue"]-diagram_data["yspace"])
	diagram_data["values_for_ynames"]+=({start+=diagram_data["yspace"]});
    }
  
  //Generera texten om den inte finns
  if (!(diagram_data["ynames"]))
    {
      diagram_data["ynames"]=
	allocate(sizeof(diagram_data["values_for_ynames"]));
      
      for(int i=0; i<sizeof(diagram_data["values_for_ynames"]); i++)
	diagram_data["ynames"][i]=no_end_zeros((string)(diagram_data["values_for_ynames"][i]));
    }
  if (!(diagram_data["xnames"]))
    {
      diagram_data["xnames"]=
	allocate(sizeof(diagram_data["values_for_xnames"]));
      
      for(int i=0; i<sizeof(diagram_data["values_for_xnames"]); i++)
	diagram_data["xnames"][i]=no_end_zeros((string)(diagram_data["values_for_xnames"][i]));
    }


  //rita bilderna f�r texten
  //ta ut xmaxynames, ymaxynames xmaxxnames ymaxxnames
  create_text(diagram_data);

  //Skapa labelstexten f�r xaxlen
  object labelimg;
  string label;
  int labelx=0;
  int labely=0;
  if (diagram_data["labels"])
    {
      label=diagram_data["labels"][0]+" ["+diagram_data["labels"][2]+"]"; //Xstorhet
      labelimg=get_font("avant_garde", 32, 0, 0, "left",0,0)->
	write(label)->scale(0,diagram_data["labelsize"]);
      labely=diagram_data["labelsize"];
      labelx=labelimg->xsize();
    }

  int ypos_for_xaxis; //avst�nd NERIFR�N!
  int xpos_for_yaxis; //avst�nd fr�n h�ger
  //Best�m var i bilden vi f�r rita graf
  diagram_data["ystart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["ystop"]=diagram_data["ysize"]-
    (int)ceil(diagram_data["linewidth"]+si)-diagram_data["labelsize"];
  if (((float)diagram_data["yminvalue"]>-LITET)&&
      ((float)diagram_data["yminvalue"]<LITET))
    diagram_data["yminvalue"]=0.0;
  
  if (diagram_data["yminvalue"]<0)
    {
      //placera ut x-axeln.
      //om detta inte funkar s� rita xaxeln l�ngst ner/l�ngst upp och r�kna om diagram_data["ystart"]
      ypos_for_xaxis=((-diagram_data["yminvalue"])*(diagram_data["ystop"]-diagram_data["ystart"]))/
	(diagram_data["ymaxvalue"]-diagram_data["yminvalue"])+diagram_data["ystart"];
      
      int minpos;
      minpos=max(labely, diagram_data["ymaxxnames"])+si*2;
      if (minpos>ypos_for_xaxis)
	{
	  ypos_for_xaxis=minpos;
	  diagram_data["ystart"]=ypos_for_xaxis+
	    diagram_data["yminvalue"]*(diagram_data["ystop"]-ypos_for_xaxis)/
	    (diagram_data["ymaxvalue"]);
	}
      else
	{
	  int maxpos;
	  maxpos=diagram_data["ysize"]-
	    (int)ceil(diagram_data["linewidth"]+si*2)-
	    diagram_data["labelsize"];
	  if (maxpos<ypos_for_xaxis)
	    {
	      ypos_for_xaxis=maxpos;
	      diagram_data["ystop"]=ypos_for_xaxis+
		diagram_data["ymaxvalue"]*(ypos_for_xaxis-diagram_data["ystart"])/
		(0-diagram_data["yminvalue"]);
	    }
	}
    }
  else
    if (diagram_data["yminvalue"]==0.0)
      {
	// s�tt x-axeln l�ngst ner och diagram_data["ystart"] p� samma st�lle.
	diagram_data["ystop"]=diagram_data["ysize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-diagram_data["labelsize"];
	ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si*2;
	diagram_data["ystart"]=ypos_for_xaxis;
      }
    else
      {
	//s�tt x-axeln l�ngst ner och diagram_data["ystart"] en aning h�gre
	diagram_data["ystop"]=diagram_data["ysize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-diagram_data["labelsize"];
	ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si*2;
	diagram_data["ystart"]=ypos_for_xaxis+si*2;
      }
  
  //xpos_for_yaxis=diagram_data["xmaxynames"]+
  // si;

  //Best�m positionen f�r y-axeln
  diagram_data["xstart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["xstop"]=diagram_data["xsize"]-
    (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
  if (((float)diagram_data["xminvalue"]>-LITET)&&
      ((float)diagram_data["xminvalue"]<LITET))
    diagram_data["xminvalue"]=0.0;
  
  if (diagram_data["xminvalue"]<0)
    {
      //placera ut y-axeln.
      //om detta inte funkar s� rita yaxeln l�ngst ner/l�ngst upp och r�kna om diagram_data["xstart"]
      xpos_for_yaxis=((-diagram_data["xminvalue"])*(diagram_data["xstop"]-diagram_data["xstart"]))/
	(diagram_data["xmaxvalue"]-diagram_data["xminvalue"])+diagram_data["xstart"];
      
      int minpos;
      minpos=diagram_data["xmaxynames"]+si*2;
      if (minpos>xpos_for_yaxis)
	{
	  xpos_for_yaxis=minpos;
	  diagram_data["xstart"]=xpos_for_yaxis+
	    diagram_data["xminvalue"]*(diagram_data["xstop"]-xpos_for_yaxis)/
	    (diagram_data["ymaxvalue"]);
	}
      else
	{
	  int maxpos;
	  maxpos=diagram_data["xsize"]-
	    (int)ceil(diagram_data["linewidth"]+si*2)-
	    labelx/2;
	  if (maxpos<xpos_for_yaxis)
	    {
	      xpos_for_yaxis=maxpos;
	      diagram_data["xstop"]=xpos_for_yaxis+
		diagram_data["xmaxvalue"]*(xpos_for_yaxis-diagram_data["xstart"])/
		(0-diagram_data["xminvalue"]);
	    }
	}
    }
  else
    if (diagram_data["xminvalue"]==0.0)
      {
	// s�tt y-axeln l�ngst ner och diagram_data["xstart"] p� samma st�lle.
	write("\nNu blev xminvalue noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");
	
	diagram_data["xstop"]=diagram_data["xsize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
	xpos_for_yaxis=diagram_data["xmaxynames"]+si*2;
	diagram_data["xstart"]=xpos_for_yaxis;
      }
    else
      {
	//s�tt y-axeln l�ngst ner och diagram_data["xstart"] en aning h�gre
	write("\nNu blev xminvalue st�rre �n noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");

	diagram_data["xstop"]=diagram_data["xsize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
	xpos_for_yaxis=diagram_data["xmaxynames"]+si*2;
	diagram_data["xstart"]=xpos_for_yaxis+si*2;
      }
  





  
  //Rita ut axlarna
  graph->setcolor(@(diagram_data["axcolor"]));
  
  write((string)diagram_data["xminvalue"]+"\n"+(string)diagram_data["xmaxvalue"]+"\n");

  //Rita xaxeln
  if ((diagram_data["xminvalue"]<=LITET)&&
      (diagram_data["xmaxvalue"]>=-LITET))
    graph->
      polygone(make_polygon_from_line(diagram_data["linewidth"], 
				      ({
					diagram_data["linewidth"],
					diagram_data["ysize"]- ypos_for_xaxis,
					diagram_data["xsize"]-
					diagram_data["linewidth"]-labelx/2, 
					diagram_data["ysize"]-ypos_for_xaxis
				      }), 
				      1, 1)[0]);
  else
    if (diagram_data["xmaxvalue"]<-LITET)
      {
	write("xpos_for_yaxis"+xpos_for_yaxis+"\n");

	//diagram_data["xstop"]-=(int)ceil(4.0/3.0*(float)si);
	graph->
	  polygone(make_polygon_from_line(diagram_data["linewidth"], 
					  ({
					    diagram_data["linewidth"],
					    diagram_data["ysize"]- ypos_for_xaxis,
					    
					    xpos_for_yaxis-4.0/3.0*si, 
					    diagram_data["ysize"]-ypos_for_xaxis,
					    
					    xpos_for_yaxis-si, 
					    diagram_data["ysize"]-ypos_for_xaxis-
					    si/2.0,
					    xpos_for_yaxis-si/1.5, 
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si/2.0,
					    
					    xpos_for_yaxis-si/3.0, 
					    diagram_data["ysize"]-ypos_for_xaxis,

					    diagram_data["xsize"]-diagram_data["linewidth"]-labelx/2, 
					    diagram_data["ysize"]-ypos_for_xaxis

					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["xminvalue"]>LITET)
	{
	  //diagram_data["xstart"]+=(int)ceil(4.0/3.0*(float)si);
	  graph->
	    polygone(make_polygon_from_line(diagram_data["linewidth"], 
					    ({
					      diagram_data["linewidth"],
					      diagram_data["ysize"]- ypos_for_xaxis,
					      
					      xpos_for_yaxis+si/3.0, 
					      diagram_data["ysize"]-ypos_for_xaxis,
					      
					      xpos_for_yaxis+si/1.5, 
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si/2.0,
					      xpos_for_yaxis+si, 
					      diagram_data["ysize"]-ypos_for_xaxis+
					      si/2.0,
					      
					      xpos_for_yaxis+4.0/3.0*si, 
					      diagram_data["ysize"]-ypos_for_xaxis,
					      
					      diagram_data["xsize"]-diagram_data["linewidth"]-labelx/2, 
					      diagram_data["ysize"]-ypos_for_xaxis
					      
					    }), 
					    1, 1)[0]);

	}
  
  //Rita pilen p� xaxeln
  graph->
    polygone(make_polygon_from_line(diagram_data["linewidth"], 
				    ({
				      diagram_data["xsize"]-
				      diagram_data["linewidth"]-
				      (float)si/2.0-labelx/2, 
				      diagram_data["ysize"]-ypos_for_xaxis-
				      (float)si/2.0,
				      diagram_data["xsize"]-
				      diagram_data["linewidth"]-labelx/2, 
				      diagram_data["ysize"]-ypos_for_xaxis,
				      diagram_data["xsize"]-
				      diagram_data["linewidth"]-
				      (float)si/2.0-labelx/2, 
				      diagram_data["ysize"]-ypos_for_xaxis+
				      (float)si/2.0
				    }), 
				    1, 1)[0]);

  //Rita yaxeln
  if ((diagram_data["yminvalue"]<=LITET)&&
      (diagram_data["ymaxvalue"]>=-LITET))
      graph->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  xpos_for_yaxis,
					  diagram_data["xsize"]-diagram_data["linewidth"],
					  
					  xpos_for_yaxis,
					  diagram_data["linewidth"]+
					  diagram_data["labelsize"]
					}), 
					1, 1)[0]);
  else
    if (diagram_data["ymaxvalue"]<-LITET)
      {
	graph->
	  polygone(make_polygon_from_line(diagram_data["linewidth"], 
					  ({
					    xpos_for_yaxis,
					    diagram_data["ysize"]-diagram_data["linewidth"],

					    xpos_for_yaxis,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si*4.0/3.0,

					    xpos_for_yaxis-si/2.0,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si,
					    
					    xpos_for_yaxis+si/2.0,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si/1.5,
					    
					    xpos_for_yaxis,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si/3.0,
					    
					    xpos_for_yaxis,
					    diagram_data["linewidth"]+
					    diagram_data["labelsize"]
					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["yminvalue"]>LITET)
	{
	  /*write("\n\n"+sprintf("%O", make_polygon_from_line(diagram_data["linewidth"], 
							   ({
							     xpos_for_yaxis,
							     diagram_data["xsize"]-diagram_data["linewidth"],
							     
							     xpos_for_yaxis,
							     diagram_data["ysize"]-ypos_for_xaxis-
							     si/3.0,
							     
							     xpos_for_yaxis-si/2.0,
							     diagram_data["ysize"]-ypos_for_xaxis-
							     si/1.5,
							     
							     xpos_for_yaxis+si/2.0,
							     diagram_data["ysize"]-ypos_for_xaxis-
							     si,
							     
							     xpos_for_yaxis,
							     diagram_data["ysize"]-ypos_for_xaxis-
							     si*4.0/3.0,
					    
							     xpos_for_yaxis,
							     diagram_data["linewidth"]
							     
							   }), 
							   1, 1)[0])+"\n\n");*/
	  graph->
	    polygone(make_polygon_from_line(diagram_data["linewidth"], 
					    ({
					      xpos_for_yaxis,
					      diagram_data["xsize"]-diagram_data["linewidth"],

					      xpos_for_yaxis,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si/3.0,
					      
					      xpos_for_yaxis-si/2.0,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si/1.5,
					    
					      xpos_for_yaxis+si/2.0,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si,
					      
					      xpos_for_yaxis,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si*4.0/3.0,
					    
					      xpos_for_yaxis+0.01, //FIXME!
					      diagram_data["linewidth"]+
					      diagram_data["labelsize"]
					      
					    }), 
					    1, 1)[0]);

	}
  
  //Rita pilen
  graph->
    polygone(make_polygon_from_line(diagram_data["linewidth"], 
				    ({
				      xpos_for_yaxis-
				      (float)si/2.0,
				      diagram_data["linewidth"]+
				      (float)si/2.0+
					  diagram_data["labelsize"],
				      
				      xpos_for_yaxis,
				      diagram_data["linewidth"]+
					  diagram_data["labelsize"],
	
				      xpos_for_yaxis+
				      (float)si/2.0,
				      diagram_data["linewidth"]+
				      (float)si/2.0+
					  diagram_data["labelsize"]
				    }), 
				    1, 1)[0]);


  //R�kna ut lite skit
  float xstart=(float)diagram_data["xstart"];
  float xmore=(-xstart+diagram_data["xstop"])/
    (diagram_data["xmaxvalue"]-diagram_data["xminvalue"]);
  float ystart=(float)diagram_data["ystart"];
  float ymore=(-ystart+diagram_data["ystop"])/
    (diagram_data["ymaxvalue"]-diagram_data["yminvalue"]);
  
  

  //Placera ut texten p� X-axeln
  int s=sizeof(diagram_data["xnamesimg"]);
  for(int i=0; i<s; i++)
    {
      graph->paste_alpha_color(diagram_data["xnamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor((diagram_data["values_for_xnames"][i]-
					   diagram_data["xminvalue"])
					  *xmore+xstart
					  -
					  diagram_data["xnamesimg"][i]->xsize()/2), 
			       (int)floor(diagram_data["ysize"]-ypos_for_xaxis+
					  si/2.0));
      graph->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  ((diagram_data["values_for_xnames"][i]-
					    diagram_data["xminvalue"])
					   *xmore+xstart),
					  diagram_data["ysize"]-ypos_for_xaxis+
					   si/4,
					  ((diagram_data["values_for_xnames"][i]-
					    diagram_data["xminvalue"])
					   *xmore+xstart),
					  diagram_data["ysize"]-ypos_for_xaxis-
					   si/4
					}), 
					1, 1)[0]);
    }

  //Placera ut texten p� Y-axeln
  s=sizeof(diagram_data["ynamesimg"]);
  for(int i=0; i<s; i++)
    {
      write("\nYmaXnames:"+diagram_data["ymaxynames"]+"\n");
      graph->paste_alpha_color(diagram_data["ynamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor(xpos_for_yaxis-
					  si/2.0-diagram_data["linewidth"]*2-
					  diagram_data["ynamesimg"][i]->xsize()),
			       (int)floor(-(diagram_data["values_for_ynames"][i]-
					    diagram_data["yminvalue"])
					  *ymore+diagram_data["ysize"]-ystart
					  -
					  diagram_data["ymaxynames"]/2));
      graph->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  xpos_for_yaxis-
					   si/4,
					  (-(diagram_data["values_for_ynames"][i]-
					     diagram_data["yminvalue"])
					   *ymore+diagram_data["ysize"]-ystart),

					  xpos_for_yaxis+
					   si/4,
					  (-(diagram_data["values_for_ynames"][i]-
					     diagram_data["yminvalue"])
					   *ymore+diagram_data["ysize"]-ystart)
					}), 
					1, 1)[0]);
    }


  //S�tt ut labels ({xstorhet, ystorhet, xenhet, yenhet})
  if (diagram_data["labels"])
    {
      graph->paste_alpha_color(labelimg, 
			       @(diagram_data["labelcolor"]), 
			       diagram_data["xsize"]-labelx-(int)ceil((float)diagram_data["linewidth"]),
			       diagram_data["ysize"]-(int)ceil((float)(ypos_for_xaxis-si)));
      
      string label;
      int x;
      int y;
      
      label=diagram_data["labels"][1]+" ["+diagram_data["labels"][3]+"]"; //Ystorhet
      labelimg=get_font("avant_garde", 32, 0, 0, "left",0,0)->
	write(label)->scale(0,diagram_data["labelsize"]);
      
      /*
	if (labelimg->xsize()> graph->xsize())
	labelimg->scale(graph->xsize(),labelimg->ysize());
      */
      x=max(0,((int)floor((float)xpos_for_yaxis)-labelimg->xsize()/2));
      x=min(x, graph->xsize()-labelimg->xsize());
      
      y=0; 

      
      if (label && sizeof(label))
	graph->paste_alpha_color(labelimg, 
				 @(diagram_data["labelcolor"]), 
				 x,
				 0);
      
      

    }

  //Rita ut datan
  int farg=0;
  write("xstart:"+diagram_data["xstart"]+"\nystart"+diagram_data["ystart"]+"\n");
  write("xstop:"+diagram_data["xstop"]+"\nystop"+diagram_data["ystop"]+"\n");

  foreach(diagram_data["datapoints"], array(float) d)
    {
      for(int i=0; i<sizeof(d); i++)
	{
	  d[i]=(d[i]-diagram_data["xminvalue"])*xmore+xstart;
	  i++;
	  d[i]=-(d[i]-diagram_data["yminvalue"])*ymore+diagram_data["ysize"]-ystart;	  
	}

      graph->setcolor(@(diagram_data["datacolors"][farg++]));
      //graph->polygone(make_polygon_from_line(diagram_data["linewidth"],d,
      //				     1, 1)[0]);
      draw(graph, diagram_data["linewidth"],d);
    }

  diagram_data["image"]=graph;
  return diagram_data;
}


int main(int argc, string *argv)
{
  write("\nRitar axlarna. Filen sparad som test.ppm\n");

  mapping(string:mixed) diagram_data;
  diagram_data=(["typ":"graph",
		 "textcolor":({0,0,0}),
		 "subtyp":"",
		 "orient":"vert",
		 "datapoints": 
		 ({ ({-1.2, 12.3, -4.01, 10.0, -4.3, 12.0 }),
		    ({-1.2, 11.3, -1.5, 11.7,  -1.0, 11.5, -1.0, 13.0, -2.0, 16.0  }),
		    ({-1.2, 13.3, 1.5, 10.1 }),
		    ({-3.2, 13.3, -3.5, 13.7} )}),
		 "fontsize":32,
		 "axcolor":({0,0,0}),
		 "bgcolor":({255,255,255}),
		 "labelcolor":({0,0,0}),
		 "datacolors":({({0,255,0}),({255,255,0}), ({0,255,255}), ({255,0,255}) }),
		 "orient":"hor",
		 "linewidth":2.2,
		 "xsize":300,
		 "ysize":200,
		 "fontsize":16,
		 "labels":({"xstor", "ystor", "xenhet", "yenhet"}),
		 "labelsize":50/*,
		 "xminvalue":0.0,
		 "yminvalue":0.0*/

  ]);
  /*
  diagram_data["datapoints"]=({({ 
    49.099998,
    155.666672,
    49.066963,
    155.399109,
    48.969841,
    155.147629,
    48.814468,
    154.927322,
    48.610172,
    154.751419,
    42.481537,
    150.665649,
    56.347851,
    146.043549,
    56.847610,
    145.701111,
    57.090267,
    145.145996,
    57.002220,
    144.546616,
    56.610172,
    144.084732,
    49.099998,
    139.077972,
    49.099998,
    2.200000,
    49.033661,
    1.823778,
    48.842648,
    1.492934,
    48.549999,
    1.247372,
    48.191013,
    1.116711,
    47.808987,
    1.116711,
    47.450001,
    1.247372,
    47.157352,
    1.492934,
    46.966339,
    1.823778,
    46.900002,
    2.200000,
    46.899998,
    139.666672,
    46.933033,
    139.934219,
    47.030159,
    140.185715,
    47.185532,
    140.406036,
    47.389832,
    140.581924,
    53.518459,
    144.667679,
    39.652149,
    149.289780,
    39.152390,
    149.632217,
    38.909737,
    150.187317,
    38.997780,
    150.786713,
    39.389828,
    151.248581,
    46.900002,
    156.255371,
    46.900002,
    197.800003,
    46.966339,
    198.176224,
    47.157352,
    198.507065,
    47.450001,
    198.752625,
    47.808987,
    198.883286,
    48.191013,
    198.883286,
    48.549999,
    198.752625,
    48.842648,
    198.507065,
    49.033661,
    198.176224,
    49.099998,
    197.800003
})});
*/

  object o=Stdio.File();
  o->open("test.ppm", "wtc");
  o->write(create_graph(diagram_data)["image"]->toppm());
  o->close();

};
