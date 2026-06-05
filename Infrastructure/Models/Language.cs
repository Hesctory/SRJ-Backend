using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Language
{
    public int Id { get; set; }

    public string? Name { get; set; }

    public virtual ICollection<Person> People { get; set; } = new List<Person>();

    public virtual ICollection<Person> PeopleNavigation { get; set; } = new List<Person>();
}
