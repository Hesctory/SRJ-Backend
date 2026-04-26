using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Language
{
    public int Id { get; set; }

    public string? Name { get; set; }

    public virtual ICollection<EducationalPerson> EducationalPeople { get; set; } = new List<EducationalPerson>();

    public virtual ICollection<EducationalPerson> EducationalPeopleNavigation { get; set; } = new List<EducationalPerson>();
}
