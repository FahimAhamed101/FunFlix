import '../models/live_channel.dart';
import '../models/movie.dart';
import '../models/series.dart';

/// The bundled catalogue.
///
/// This is what makes the app runnable with no portal, no network and no
/// setup — useful for looking at the UI, and for demonstrating that the
/// screens genuinely do not care where the data came from.

const List<Movie> kSampleMovies = <Movie>[
  Movie(
    id: 'inception',
    title: 'Inception',
    synopsis:
        'A thief who steals corporate secrets through dream-sharing technology is '
        'given the inverse task of planting an idea into the mind of a C.E.O.',
    shelf: 'Sci-Fi',
    year: 2010,
    rating: 8.8,
    runtimeMinutes: 148,
    genres: <String>['Sci-Fi', 'Thriller'],
    cast: <String>['Leonardo DiCaprio', 'Joseph Gordon-Levitt', 'Elliot Page'],
    posterSeed: 'inception',
  ),
  Movie(
    id: 'blade-runner-2049',
    title: 'Blade Runner 2049',
    synopsis:
        'A young blade runner unearths a long-buried secret that has the potential '
        'to plunge what is left of society into chaos.',
    shelf: 'Sci-Fi',
    year: 2017,
    rating: 8.0,
    runtimeMinutes: 164,
    genres: <String>['Sci-Fi', 'Drama', 'Mystery'],
    cast: <String>['Ryan Gosling', 'Harrison Ford', 'Ana de Armas'],
    posterSeed: 'blade-runner-2049',
  ),
  Movie(
    id: 'arrival',
    title: 'Arrival',
    synopsis:
        'A linguist is recruited by the military to assist in translating '
        'alien communications after twelve craft appear around the world.',
    shelf: 'Sci-Fi',
    year: 2016,
    rating: 7.9,
    runtimeMinutes: 116,
    genres: <String>['Sci-Fi', 'Drama'],
    cast: <String>['Amy Adams', 'Jeremy Renner', 'Forest Whitaker'],
    posterSeed: 'arrival',
  ),
  Movie(
    id: 'dune-part-two',
    title: 'Dune: Part Two',
    synopsis:
        'Paul Atreides unites with the Fremen to wage war against the House '
        'Harkonnen, torn between the love of his life and the fate of the universe.',
    shelf: 'Sci-Fi',
    year: 2024,
    rating: 8.5,
    runtimeMinutes: 166,
    genres: <String>['Sci-Fi', 'Adventure'],
    cast: <String>['Timothee Chalamet', 'Zendaya', 'Rebecca Ferguson'],
    posterSeed: 'dune-part-two',
  ),
  Movie(
    id: 'parasite',
    title: 'Parasite',
    synopsis:
        'Greed and class discrimination threaten the newly formed symbiotic '
        'relationship between the wealthy Park family and the destitute Kim clan.',
    shelf: 'Thriller',
    year: 2019,
    rating: 8.5,
    runtimeMinutes: 132,
    genres: <String>['Thriller', 'Drama', 'Comedy'],
    cast: <String>['Song Kang-ho', 'Lee Sun-kyun', 'Cho Yeo-jeong'],
    posterSeed: 'parasite',
  ),
  Movie(
    id: 'get-out',
    title: 'Get Out',
    synopsis:
        'A young Black man visits his white girlfriend\'s family estate and '
        'uncovers a nightmare hidden beneath their unsettling hospitality.',
    shelf: 'Thriller',
    year: 2017,
    rating: 7.8,
    runtimeMinutes: 104,
    genres: <String>['Horror', 'Thriller', 'Mystery'],
    cast: <String>['Daniel Kaluuya', 'Allison Williams', 'Bradley Whitford'],
    posterSeed: 'get-out',
  ),
  Movie(
    id: 'heat',
    title: 'Heat',
    synopsis:
        'A veteran detective and a career thief circle each other across Los '
        'Angeles, each recognising himself in the other.',
    shelf: 'Thriller',
    year: 1995,
    rating: 8.3,
    runtimeMinutes: 170,
    genres: <String>['Crime', 'Drama', 'Thriller'],
    cast: <String>['Al Pacino', 'Robert De Niro', 'Val Kilmer'],
    posterSeed: 'heat',
  ),
  Movie(
    id: 'whiplash',
    title: 'Whiplash',
    synopsis:
        'A promising young drummer enrols at a cut-throat music conservatory '
        'where an abusive instructor will stop at nothing to realise a student\'s '
        'potential.',
    shelf: 'Drama',
    year: 2014,
    rating: 8.5,
    runtimeMinutes: 106,
    genres: <String>['Drama', 'Music'],
    cast: <String>['Miles Teller', 'J.K. Simmons', 'Paul Reiser'],
    posterSeed: 'whiplash',
  ),
  Movie(
    id: 'the-social-network',
    title: 'The Social Network',
    synopsis:
        'The founding of a social network, and the lawsuits that followed, told '
        'as a study of ambition, betrayal and the cost of being right.',
    shelf: 'Drama',
    year: 2010,
    rating: 7.8,
    runtimeMinutes: 120,
    genres: <String>['Drama', 'Biography'],
    cast: <String>['Jesse Eisenberg', 'Andrew Garfield', 'Justin Timberlake'],
    posterSeed: 'the-social-network',
  ),
  Movie(
    id: 'grand-budapest',
    title: 'The Grand Budapest Hotel',
    synopsis:
        'A legendary concierge and his trusted lobby boy become embroiled in the '
        'theft of a priceless painting and the battle for an enormous family fortune.',
    shelf: 'Comedy',
    year: 2014,
    rating: 8.1,
    runtimeMinutes: 99,
    genres: <String>['Comedy', 'Adventure', 'Crime'],
    cast: <String>['Ralph Fiennes', 'Tony Revolori', 'Saoirse Ronan'],
    posterSeed: 'grand-budapest',
  ),
  Movie(
    id: 'spirited-away',
    title: 'Spirited Away',
    synopsis:
        'A ten-year-old girl wanders into a world ruled by gods, witches and '
        'spirits, where humans are changed into beasts.',
    shelf: 'Animation',
    year: 2001,
    rating: 8.6,
    runtimeMinutes: 125,
    genres: <String>['Animation', 'Fantasy', 'Adventure'],
    cast: <String>['Rumi Hiiragi', 'Miyu Irino', 'Mari Natsuki'],
    posterSeed: 'spirited-away',
  ),
  Movie(
    id: 'coco',
    title: 'Coco',
    synopsis:
        'A boy who dreams of becoming a musician is transported to the Land of '
        'the Dead, where he seeks his great-great-grandfather\'s blessing.',
    shelf: 'Animation',
    year: 2017,
    rating: 8.4,
    runtimeMinutes: 105,
    genres: <String>['Animation', 'Family', 'Fantasy'],
    cast: <String>['Anthony Gonzalez', 'Gael Garcia Bernal', 'Benjamin Bratt'],
    posterSeed: 'coco',
  ),
  Movie(
    id: 'mad-max-fury-road',
    title: 'Mad Max: Fury Road',
    synopsis:
        'In a desert wasteland, a drifter and a runaway warrior flee a tyrant '
        'across the dunes in a convoy that never stops moving.',
    shelf: 'Action',
    year: 2015,
    rating: 8.1,
    runtimeMinutes: 120,
    genres: <String>['Action', 'Adventure', 'Sci-Fi'],
    cast: <String>['Tom Hardy', 'Charlize Theron', 'Nicholas Hoult'],
    posterSeed: 'mad-max-fury-road',
  ),
  Movie(
    id: 'the-dark-knight',
    title: 'The Dark Knight',
    synopsis:
        'Batman, Gordon and Harvey Dent confront the Joker, an anarchist whose '
        'only goal is to prove that everyone breaks eventually.',
    shelf: 'Action',
    year: 2008,
    rating: 9.0,
    runtimeMinutes: 152,
    genres: <String>['Action', 'Crime', 'Drama'],
    cast: <String>['Christian Bale', 'Heath Ledger', 'Aaron Eckhart'],
    posterSeed: 'the-dark-knight',
  ),

  // --- The "hidden" VOD categories real panels carry ----------------------
  // Documentaries, concerts and (when the provider account includes it) adult
  // content are just more movie shelves — the app groups by the panel's own
  // category, so an adult shelf only appears if the portal actually has one.
  Movie(
    id: 'free-solo',
    title: 'Free Solo',
    synopsis:
        'A rock climber attempts to scale El Capitan without ropes, capturing '
        'a landmark of documentary filmmaking.',
    shelf: 'Documentaries',
    year: 2018,
    rating: 8.1,
    runtimeMinutes: 100,
    genres: <String>['Documentary'],
    cast: <String>['Alex Honnold', 'Tommy Caldwell'],
    posterSeed: 'free-solo',
  ),
  Movie(
    id: 'the-last-dance',
    title: 'The Last Dance',
    synopsis:
        'A documentary series on the career of Michael Jordan and the Chicago '
        'Bulls through their 1990s dynasty.',
    shelf: 'Documentaries',
    year: 2020,
    rating: 9.1,
    runtimeMinutes: 505,
    genres: <String>['Documentary', 'Sport'],
    cast: <String>['Michael Jordan'],
    posterSeed: 'the-last-dance',
  ),
  Movie(
    id: 'live-at-wembley',
    title: 'Live at Wembley',
    synopsis:
        'A recorded stadium concert, front to back — the kind of release panels '
        'file under music videos rather than films.',
    shelf: 'Concerts & Music',
    year: 2019,
    rating: 8.4,
    runtimeMinutes: 118,
    genres: <String>['Music', 'Concert'],
    cast: <String>['The Headliners'],
    posterSeed: 'live-at-wembley',
  ),
  Movie(
    id: 'neon-nights-tour',
    title: 'Neon Nights Tour',
    synopsis:
        'A neon-lit arena show from a synth-pop act, filmed across three nights.',
    shelf: 'Concerts & Music',
    year: 2022,
    rating: 7.6,
    runtimeMinutes: 96,
    genres: <String>['Music', 'Concert'],
    cast: <String>['Neon Nights'],
    posterSeed: 'neon-nights-tour',
  ),
  Movie(
    id: 'after-dark',
    title: 'After Dark',
    synopsis:
        'Sample adult title. Real panels gate this shelf behind the account; the '
        'app shows it only when the provider actually returns it.',
    shelf: 'Adult',
    year: 2021,
    rating: 6.2,
    runtimeMinutes: 88,
    genres: <String>['Adult'],
    cast: <String>['—'],
    posterSeed: 'after-dark',
  ),
];

/// Sample series.
///
/// Season counts are carried so the sample catalogue exercises the same code
/// path a real portal does — including the season picker on the detail screen.
const List<TvSeries> kSampleSeries = <TvSeries>[
  TvSeries(
    id: 'breaking-bad',
    title: 'Breaking Bad',
    synopsis:
        'A chemistry teacher diagnosed with terminal cancer turns to '
        'manufacturing methamphetamine to secure his family\'s future.',
    shelf: 'Crime Drama',
    year: 2008,
    rating: 9.5,
    genres: <String>['Crime', 'Drama', 'Thriller'],
    cast: <String>['Bryan Cranston', 'Aaron Paul', 'Anna Gunn'],
    posterSeed: 'breaking-bad',
    seasonCount: 5,
    episodeRunTime: 47,
  ),
  TvSeries(
    id: 'the-sopranos',
    title: 'The Sopranos',
    synopsis:
        'A New Jersey mob boss balances the demands of two families — the one '
        'he runs and the one he goes home to.',
    shelf: 'Crime Drama',
    year: 1999,
    rating: 9.2,
    genres: <String>['Crime', 'Drama'],
    cast: <String>['James Gandolfini', 'Edie Falco', 'Michael Imperioli'],
    posterSeed: 'the-sopranos',
    seasonCount: 6,
    episodeRunTime: 55,
  ),
  TvSeries(
    id: 'dark',
    title: 'Dark',
    synopsis:
        'Four families search for a missing child and uncover a time-travelling '
        'conspiracy stretching across three generations.',
    shelf: 'Sci-Fi',
    year: 2017,
    rating: 8.7,
    genres: <String>['Sci-Fi', 'Mystery', 'Drama'],
    cast: <String>['Louis Hofmann', 'Lisa Vicari', 'Oliver Masucci'],
    posterSeed: 'dark',
    seasonCount: 3,
    episodeRunTime: 55,
  ),
  TvSeries(
    id: 'the-last-of-us',
    title: 'The Last of Us',
    synopsis:
        'Twenty years after a fungal pandemic collapses civilisation, a smuggler '
        'escorts a teenage girl across a ruined America.',
    shelf: 'Sci-Fi',
    year: 2023,
    rating: 8.7,
    genres: <String>['Drama', 'Horror', 'Adventure'],
    cast: <String>['Pedro Pascal', 'Bella Ramsey', 'Anna Torv'],
    posterSeed: 'the-last-of-us',
    seasonCount: 2,
    episodeRunTime: 58,
  ),
  TvSeries(
    id: 'severance',
    title: 'Severance',
    synopsis:
        'Employees at a mysterious company undergo a procedure that divides '
        'their work memories from their personal ones.',
    shelf: 'Sci-Fi',
    year: 2022,
    rating: 8.7,
    genres: <String>['Sci-Fi', 'Thriller', 'Mystery'],
    cast: <String>['Adam Scott', 'Britt Lower', 'Patricia Arquette'],
    posterSeed: 'severance',
    seasonCount: 2,
    episodeRunTime: 50,
  ),
  TvSeries(
    id: 'succession',
    title: 'Succession',
    synopsis:
        'The children of a media mogul manoeuvre for control of the empire as '
        'their father\'s health begins to fail.',
    shelf: 'Drama',
    year: 2018,
    rating: 8.9,
    genres: <String>['Drama', 'Comedy'],
    cast: <String>['Brian Cox', 'Jeremy Strong', 'Sarah Snook'],
    posterSeed: 'succession',
    seasonCount: 4,
    episodeRunTime: 60,
  ),
  TvSeries(
    id: 'the-bear',
    title: 'The Bear',
    synopsis:
        'A fine-dining chef returns home to run his late brother\'s chaotic '
        'sandwich shop.',
    shelf: 'Drama',
    year: 2022,
    rating: 8.6,
    genres: <String>['Drama', 'Comedy'],
    cast: <String>['Jeremy Allen White', 'Ayo Edebiri', 'Ebon Moss-Bachrach'],
    posterSeed: 'the-bear',
    seasonCount: 3,
    episodeRunTime: 32,
  ),
  TvSeries(
    id: 'chernobyl',
    title: 'Chernobyl',
    synopsis:
        'A dramatisation of the 1986 nuclear disaster and the people who '
        'contained it.',
    shelf: 'Drama',
    year: 2019,
    rating: 9.3,
    genres: <String>['Drama', 'History', 'Thriller'],
    cast: <String>['Jared Harris', 'Stellan Skarsgard', 'Emily Watson'],
    posterSeed: 'chernobyl',
    seasonCount: 1,
    episodeRunTime: 65,
  ),
  TvSeries(
    id: 'arcane',
    title: 'Arcane',
    synopsis:
        'Two sisters end up on opposite sides of a war between a gleaming city '
        'and its oppressed underbelly.',
    shelf: 'Animation',
    year: 2021,
    rating: 9.0,
    genres: <String>['Animation', 'Action', 'Fantasy'],
    cast: <String>['Hailee Steinfeld', 'Ella Purnell', 'Kevin Alejandro'],
    posterSeed: 'arcane',
    seasonCount: 2,
    episodeRunTime: 41,
  ),
  TvSeries(
    id: 'the-boys',
    title: 'The Boys',
    synopsis:
        'A covert team of vigilantes sets out to take down corrupt superheroes '
        'who abuse their powers.',
    shelf: 'Action',
    year: 2019,
    rating: 8.7,
    genres: <String>['Action', 'Comedy', 'Sci-Fi'],
    cast: <String>['Karl Urban', 'Jack Quaid', 'Antony Starr'],
    posterSeed: 'the-boys',
    seasonCount: 4,
    episodeRunTime: 60,
  ),
  TvSeries(
    id: 'planete-terre',
    title: 'Planet Earth II',
    synopsis:
        'A landmark natural-history series filmed across every continent, from '
        'island peaks to the concrete jungle.',
    shelf: 'Documentary',
    year: 2016,
    rating: 9.4,
    genres: <String>['Documentary', 'Nature'],
    cast: <String>['David Attenborough'],
    posterSeed: 'planete-terre',
    seasonCount: 1,
    episodeRunTime: 50,
  ),

  // --- The "hidden" series categories real panels carry -------------------
  // Reality, talk shows and complete anime seasons are just more series
  // shelves — the detail screen's season picker and episode list work exactly
  // the same, however the panel chose to categorise them.
  TvSeries(
    id: 'the-villa',
    title: 'The Villa',
    synopsis:
        'A reality competition where strangers live together and vote each '
        'other out week by week.',
    shelf: 'Reality & Talk',
    year: 2023,
    rating: 6.8,
    genres: <String>['Reality', 'Competition'],
    cast: <String>['Host A', 'Cast B'],
    posterSeed: 'the-villa',
    seasonCount: 9,
    episodeRunTime: 60,
  ),
  TvSeries(
    id: 'late-night-couch',
    title: 'Late Night Couch',
    synopsis:
        'A nightly talk show with celebrity interviews, sketches and a house '
        'band.',
    shelf: 'Reality & Talk',
    year: 2022,
    rating: 7.3,
    genres: <String>['Talk Show'],
    cast: <String>['The Host'],
    posterSeed: 'late-night-couch',
    seasonCount: 4,
    episodeRunTime: 45,
  ),
  TvSeries(
    id: 'spirited-away-anime',
    title: 'Spirited Away',
    synopsis:
        'A complete animated series organised by season, exactly how panels '
        'file their anime collections.',
    shelf: 'Anime & Cartoons',
    year: 2021,
    rating: 8.7,
    genres: <String>['Anime', 'Animation'],
    cast: <String>['Voice Cast'],
    posterSeed: 'spirited-away-anime',
    seasonCount: 5,
    episodeRunTime: 24,
  ),
  TvSeries(
    id: 'mecha-front',
    title: 'Mecha Front',
    synopsis:
        'A long-running animated saga, every season present and browsable.',
    shelf: 'Anime & Cartoons',
    year: 2019,
    rating: 8.2,
    genres: <String>['Anime', 'Sci-Fi'],
    cast: <String>['Voice Cast'],
    posterSeed: 'mecha-front',
    seasonCount: 7,
    episodeRunTime: 24,
  ),
];

/// Stand-in channels for demo mode.
///
/// No [LiveChannel.streamUrl] on purpose: there is nothing legitimate to point
/// a sample at, so the player shows its "no stream" state instead of a dead
/// link. The tiles, tabs and search are all real.
const List<LiveChannel> kSampleChannels = <LiveChannel>[
  LiveChannel(id: 's-news-1', name: 'Atlas News 24', category: 'News'),
  LiveChannel(id: 's-news-2', name: 'Meridian World', category: 'News'),
  LiveChannel(id: 's-news-3', name: 'Cityline Local', category: 'News'),
  LiveChannel(id: 's-news-4', name: 'Brief Room', category: 'News'),
  LiveChannel(
    id: 's-sport-1',
    name: 'Overtime Sports 1',
    category: 'Sports',
    hasArchive: true,
  ),
  LiveChannel(
    id: 's-sport-2',
    name: 'Overtime Sports 2',
    category: 'Sports',
    hasArchive: true,
  ),
  LiveChannel(id: 's-sport-3', name: 'Grandstand Motorsport', category: 'Sports'),
  LiveChannel(id: 's-sport-4', name: 'Court Side', category: 'Sports'),
  LiveChannel(id: 's-film-1', name: 'Reelhouse Premiere', category: 'Movies'),
  LiveChannel(id: 's-film-2', name: 'Reelhouse Classics', category: 'Movies'),
  LiveChannel(id: 's-film-3', name: 'Nocturne Thrillers', category: 'Movies'),
  LiveChannel(id: 's-doc-1', name: 'Deep Field', category: 'Documentary'),
  LiveChannel(id: 's-doc-2', name: 'Archive Room', category: 'Documentary'),
  LiveChannel(id: 's-doc-3', name: 'Blue Planet Live', category: 'Documentary'),
  LiveChannel(id: 's-kids-1', name: 'Pipsqueak TV', category: 'Kids'),
  LiveChannel(id: 's-kids-2', name: 'Cartoon Carousel', category: 'Kids'),
  LiveChannel(id: 's-music-1', name: 'Loud Frequency', category: 'Music'),
  LiveChannel(id: 's-music-2', name: 'Slow Room', category: 'Music'),

  // --- The "hidden" live categories real panels carry ---------------------
  // None of these need special handling: they are just more live categories,
  // so they surface as more tabs. Radio is flagged audio-only so the sheet
  // advertises what it is.
  LiveChannel(
    id: 's-247-1',
    name: 'Friends Loop',
    category: '24/7 Channels',
  ),
  LiveChannel(
    id: 's-247-2',
    name: 'Simpsons Forever',
    category: '24/7 Channels',
  ),
  LiveChannel(
    id: 's-247-3',
    name: 'Office Rewind',
    category: '24/7 Channels',
  ),
  LiveChannel(
    id: 's-radio-1',
    name: 'Capital FM',
    category: 'Radio',
    audioOnly: true,
  ),
  LiveChannel(
    id: 's-radio-2',
    name: 'Jazz Lounge',
    category: 'Radio',
    audioOnly: true,
  ),
  LiveChannel(
    id: 's-radio-3',
    name: 'World Service',
    category: 'Radio',
    audioOnly: true,
  ),
  LiveChannel(
    id: 's-ppv-1',
    name: 'UFC Main Card',
    category: 'PPV & Sports',
  ),
  LiveChannel(
    id: 's-ppv-2',
    name: 'Title Fight Night',
    category: 'PPV & Sports',
  ),
];
