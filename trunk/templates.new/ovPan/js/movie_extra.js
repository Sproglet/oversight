function genre_icon()
	{
	var genre = [:$%GENRE:];
	d1 = genre.toString().charAt(0);
	
	genre_icon = d1 + 'i';
	document.write(genre);
	}