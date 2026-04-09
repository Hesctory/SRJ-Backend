using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Student
{
    public int EducationalPersonId { get; set; }

    public string StudentCode { get; set; } = null!;

    public int BirthUbigeoId { get; set; }

    public bool HasDisability { get; set; }

    public virtual Ubigeo BirthUbigeo { get; set; } = null!;

    public virtual Disability? Disability { get; set; }

    public virtual EducationalPerson EducationalPerson { get; set; } = null!;

    public virtual StudentHome? StudentHome { get; set; }
}
