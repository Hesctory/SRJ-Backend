using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Gender
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<Person> People { get; set; } = new List<Person>();
}
